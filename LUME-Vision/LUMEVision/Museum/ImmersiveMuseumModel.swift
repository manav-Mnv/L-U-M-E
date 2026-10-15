import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine
import Observation

/// Drives the life-size museum in the immersive space.
///
/// The immersive space's origin sits on the floor under the user, so podiums stand at y = 0.
/// Vision Pro has no compass: the user faces north once and pinches "Set North", and
/// GPS-pinned memories are then placed in the real direction of where they happened.
@MainActor
@Observable
final class ImmersiveMuseumModel {
    enum Calibration {
        case needed, done, skipped
    }

    struct Status: Equatable {
        var message: String
        var icon: String
    }

    /// Added to the RealityView content.
    let root = Entity()

    private(set) var calibration: Calibration = .needed
    private(set) var status = Status(message: "Preparing the museum…", icon: "hourglass")
    private(set) var placedIDs: Set<UUID> = []
    private(set) var memories: [MemoryItem] = []
    private(set) var isReady = false

    /// The memory the next floor pinch will place.
    var selectedID: UUID?
    /// The podium whose info card is showing.
    private(set) var inspectedID: UUID?

    @ObservationIgnored private let floor = Entity()
    @ObservationIgnored private var template: Entity?
    @ObservationIgnored private var podiums: [UUID: Entity] = [:]
    @ObservationIgnored private var captions: [UUID: String] = [:]
    @ObservationIgnored private var north: SIMD3<Float> = [0, 0, -1]
    @ObservationIgnored private var hasPlacedGPSMemories = false
    @ObservationIgnored private let session = ARKitSession()
    @ObservationIgnored private let worldTracking = WorldTrackingProvider()
    @ObservationIgnored private var isWorldTrackingRunning = false
    @ObservationIgnored private let locationManager = LocationManager()
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    // Gesture bookkeeping
    @ObservationIgnored private var dragOffset: SIMD3<Float>?
    @ObservationIgnored private var rotationStart: simd_quatf?
    @ObservationIgnored private var scaleStart: Float?

    init() {
        // An invisible floor that catches "look at the floor and pinch" to place a podium.
        floor.name = "floor"
        floor.components.set(CollisionComponent(shapes: [.generateBox(width: 40, height: 0.02, depth: 40)]))
        floor.components.set(InputTargetComponent())
        floor.position.y = -0.01
        root.addChild(floor)
    }

    var inspectedMemory: MemoryItem? {
        memories.first { $0.id == inspectedID }
    }

    func caption(for id: UUID) -> String? {
        captions[id]
    }

    // MARK: - Lifecycle

    func start() async {
        locationManager.start()
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.placeGPSMemoriesIfReady() }
            }
            .store(in: &cancellables)

        if WorldTrackingProvider.isSupported {
            do {
                try await session.run([worldTracking])
                isWorldTrackingRunning = true
            } catch {
                print("World tracking unavailable: \(error)")
            }
        }

        template = await PodiumFactory.template()
        isReady = true
        status = Status(message: "Which way is north? Turn to face north, then pinch Set North.", icon: "location.north.circle")
    }

    func stop() {
        session.stop()
        locationManager.stop()
        cancellables.removeAll()
    }

    func update(memories: [MemoryItem]) {
        self.memories = memories
        if selectedID == nil || !memories.contains(where: { $0.id == selectedID }) {
            selectedID = memories.first { !placedIDs.contains($0.id) }?.id ?? memories.first?.id
        }
        // Drop podiums whose memory was deleted in the journal.
        for id in podiums.keys where !memories.contains(where: { $0.id == id }) {
            remove(id)
        }
    }

    // MARK: - North calibration

    /// Uses the direction the user is facing right now as true north.
    func setNorth() {
        north = devicePose()?.forward ?? [0, 0, -1]
        calibration = .done
        hasPlacedGPSMemories = false
        let pinnedCount = memories.filter { $0.coordinate != nil }.count
        if pinnedCount == 0 {
            status = Status(message: "North set. Pick a memory below, then look at the floor and pinch to place it.", icon: "hand.pinch")
        } else if locationManager.isDenied {
            status = Status(message: "North set, but location access is off — place memories by pinching the floor.", icon: "location.slash")
        } else {
            status = Status(message: "North set. Finding your location to place \(pinnedCount) pinned \(pinnedCount == 1 ? "memory" : "memories")…", icon: "location.magnifyingglass")
        }
        placeGPSMemoriesIfReady()
    }

    func skipCalibration() {
        calibration = .skipped
        status = Status(message: "Pick a memory below, then look at the floor and pinch to place it.", icon: "hand.pinch")
    }

    // MARK: - GPS placement

    private func placeGPSMemoriesIfReady() {
        guard calibration == .done, !hasPlacedGPSMemories, template != nil,
              let location = locationManager.location,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy < 1000 else { return }

        let pinned = memories.filter { $0.coordinate != nil && !placedIDs.contains($0.id) }
        hasPlacedGPSMemories = true
        guard !pinned.isEmpty else { return }

        let viewer = devicePose()?.position ?? [0, 0, 0]
        let origin = SIMD3<Float>(viewer.x, 0, viewer.z)
        var usedSpots: [SIMD3<Float>] = []

        for memory in pinned {
            guard let coordinate = memory.coordinate else { continue }
            let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = location.distance(from: target)
            let bearing = GeoPlacement.bearing(from: location.coordinate, to: coordinate)
            let direction = GeoPlacement.direction(bearing: bearing, north: north)

            var radius = GeoPlacement.walkableRadius(forDistance: distance)
            var spot = origin + direction * radius
            // Push podiums that would collide further out along the same bearing.
            while usedSpots.contains(where: { simd_distance($0, spot) < 1.4 }) {
                radius += 1.4
                spot = origin + direction * radius
            }
            usedSpots.append(spot)

            place(memory, at: spot, facing: origin, caption: GeoPlacement.distanceCaption(distance: distance, bearing: bearing))
        }

        let noun = pinned.count == 1 ? "memory stands" : "memories stand"
        status = Status(message: "\(pinned.count) \(noun) around you, pointing to where they happened. Walk up to read them.", icon: "location.north.line.fill")
        selectNextUnplaced()
    }

    // MARK: - Tap placement & inspection

    func handleTap(on entity: Entity, at scenePosition: SIMD3<Float>) {
        if let podium = PodiumFactory.podium(containing: entity) {
            inspectedID = inspectedID == podium.memoryID ? nil : podium.memoryID
            return
        }
        guard entity === floor else { return }
        placeSelectedMemory(at: scenePosition)
    }

    private func placeSelectedMemory(at point: SIMD3<Float>) {
        guard template != nil else {
            status = Status(message: "Preparing the podiums… try again in a moment.", icon: "hourglass")
            return
        }
        guard let memory = memories.first(where: { $0.id == selectedID }) else {
            status = Status(message: "Pick a memory below first.", icon: "hand.tap")
            return
        }
        let viewer = devicePose()?.position ?? [0, 1.6, 0]
        place(memory, at: [point.x, 0, point.z], facing: [viewer.x, 0, viewer.z], caption: captions[memory.id])
        status = Status(message: "Placed “\(memory.displayTitle)”. Pinch and drag to move it; use two hands to turn or resize it.", icon: "checkmark.circle")
        selectNextUnplaced()
    }

    func closeInfoCard() {
        inspectedID = nil
    }

    func remove(_ id: UUID) {
        podiums.removeValue(forKey: id)?.removeFromParent()
        placedIDs.remove(id)
        captions.removeValue(forKey: id)
        if inspectedID == id { inspectedID = nil }
    }

    func reset() {
        for id in Array(podiums.keys) { remove(id) }
        hasPlacedGPSMemories = false
        calibration = .needed
        selectedID = memories.first?.id
        status = Status(message: "Fresh start. Turn to face north, then pinch Set North.", icon: "arrow.counterclockwise")
    }

    private func selectNextUnplaced() {
        if let next = memories.first(where: { !placedIDs.contains($0.id) }) {
            selectedID = next.id
        }
    }

    private func place(_ memory: MemoryItem, at position: SIMD3<Float>, facing target: SIMD3<Float>, caption: String?) {
        guard let template else { return }
        podiums.removeValue(forKey: memory.id)?.removeFromParent()
        if let caption { captions[memory.id] = caption }

        let podium = PodiumFactory.makePodium(for: memory, caption: caption, template: template)
        // The podium's front is +Z; turn it toward the viewer.
        let yaw = atan2(target.x - position.x, target.z - position.z)
        let finalTransform = Transform(scale: .one, rotation: simd_quatf(angle: yaw, axis: [0, 1, 0]), translation: .zero)
        podium.transform = Transform(scale: SIMD3(repeating: 0.01), rotation: finalTransform.rotation, translation: .zero)

        let container = Entity()
        container.position = position
        container.addChild(podium)
        root.addChild(container)
        podium.move(to: finalTransform, relativeTo: container, duration: 0.8, timingFunction: .easeOut)

        podiums[memory.id] = container
        placedIDs.insert(memory.id)
    }

    // MARK: - Podium gestures

    func drag(_ entity: Entity, to scenePosition: SIMD3<Float>) {
        guard let podium = PodiumFactory.podium(containing: entity), let container = podium.entity.parent else { return }
        // Keep the spot you grabbed under your hand instead of snapping the podium's base to it.
        if dragOffset == nil { dragOffset = container.position - scenePosition }
        let target = scenePosition + (dragOffset ?? .zero)
        container.position = [target.x, 0, target.z]
    }

    func endDrag() {
        dragOffset = nil
    }

    func rotate(_ entity: Entity, by angle: Float) {
        guard let podium = PodiumFactory.podium(containing: entity) else { return }
        if rotationStart == nil { rotationStart = podium.entity.orientation }
        podium.entity.orientation = (rotationStart ?? podium.entity.orientation) * simd_quatf(angle: angle, axis: [0, 1, 0])
    }

    func endRotation() {
        rotationStart = nil
    }

    func scale(_ entity: Entity, by magnification: Float) {
        guard let podium = PodiumFactory.podium(containing: entity) else { return }
        if scaleStart == nil { scaleStart = podium.entity.scale.x }
        let scale = min(max((scaleStart ?? 1) * magnification, 0.25), 1.6)
        podium.entity.scale = SIMD3(repeating: scale)
    }

    func endScale() {
        scaleStart = nil
    }

    // MARK: - Info card

    /// Floats the info card above the inspected podium, always turned toward the viewer.
    func updateInfoCard(_ card: Entity?) {
        guard let card else { return }
        guard let id = inspectedID, let container = podiums[id] else {
            card.removeFromParent()
            return
        }
        if card.parent !== root {
            root.addChild(card)
            card.components.set(BillboardComponent())
        }
        let top = container.visualBounds(relativeTo: root).max.y
        card.position = [container.position.x, max(top, 0.8) + 0.3, container.position.z]
    }

    // MARK: - Device pose

    private func devicePose() -> (position: SIMD3<Float>, forward: SIMD3<Float>)? {
        guard isWorldTrackingRunning,
              let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return nil }
        let transform = anchor.originFromAnchorTransform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        var forward = -SIMD3<Float>(transform.columns.2.x, 0, transform.columns.2.z)
        if simd_length(forward) < 0.001 { forward = [0, 0, -1] }
        return (position, simd_normalize(forward))
    }
}
