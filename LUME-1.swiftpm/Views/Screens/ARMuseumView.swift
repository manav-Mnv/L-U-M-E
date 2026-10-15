import SwiftUI
import RealityKit
@preconcurrency import ARKit
import CoreLocation
import Combine

/// Drives the memory museum: the AR session (or a 3D preview gallery where AR isn't available),
/// podium placement by GPS / tap / image detection, and texture caching.
@MainActor
final class MuseumController: NSObject, ObservableObject {
    enum Mode {
        /// Real world tracking on an AR-capable iPad.
        case augmented
        /// Virtual gallery, used in the Simulator and on devices without world tracking.
        case preview
    }

    struct Status: Hashable {
        var message: String
        var icon: String = "sparkles"
        var isError = false
    }

    let memories: [MemoryItem]
    let mode: Mode
    let arView: ARView

    @Published private(set) var placedIDs: Set<UUID> = []
    @Published private(set) var selectedID: UUID?
    @Published private(set) var status: Status

    private let locationManager = LocationManager()
    /// Loaded asynchronously (see `PodiumLibrary`); placement waits until it's ready.
    private var standTemplate: Entity?
    private var textureCache: [String: TextureResource] = [:]
    private var podiums: [UUID: Entity] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var isRunning = false

    // AR state
    private var configuration = ARWorldTrackingConfiguration()
    private var floorY: Float?
    private var hasPlacedGPSMemories = false
    private var isTrackingNormal = false

    // Preview gallery state
    private let galleryRoot = Entity()
    private let previewCamera = PerspectiveCamera()
    private var galleryRadius: Float = 3
    private var previewAngles: [UUID: Float] = [:]
    private var orbitAngle: Float = 0
    private var gestureStartAngle: Float = 0
    private static let defaultCameraZ: Float = 2.4
    private var cameraZ: Float = MuseumController.defaultCameraZ
    private var gestureStartCameraZ: Float = MuseumController.defaultCameraZ

    init(memories: [MemoryItem]) {
        self.memories = memories
        let supportsAR = ARWorldTrackingConfiguration.isSupported
        mode = supportsAR ? .augmented : .preview
        arView = ARView(frame: .zero, cameraMode: supportsAR ? .ar : .nonAR, automaticallyConfigureSession: false)
        status = supportsAR
            ? Status(message: "Move your iPad slowly so LUME can find the floor.", icon: "viewfinder")
            : Status(message: "Preparing your museum…", icon: "hourglass")
        super.init()
        selectedID = memories.first?.id
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    var selectedMemory: MemoryItem? {
        memories.first { $0.id == selectedID }
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        // The camera feed starts right away; podiums appear once the model has loaded.
        if mode == .augmented { startAR() }

        Task { [weak self] in
            let template = await PodiumLibrary.template()
            guard let self, self.isRunning else { return }
            self.standTemplate = template
            switch self.mode {
            case .augmented: self.placeGPSMemoriesIfReady()
            case .preview: self.buildPreviewGallery()
            }
        }
    }

    func stop() {
        isRunning = false
        if mode == .augmented {
            arView.session.pause()
            locationManager.stop()
        }
    }

    func reset() {
        for podium in podiums.values { podium.removeFromParent() }
        podiums.removeAll()
        placedIDs.removeAll()
        selectedID = memories.first?.id

        switch mode {
        case .augmented:
            floorY = nil
            hasPlacedGPSMemories = false
            isTrackingNormal = false
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            status = Status(message: "Fresh start — scan the floor again.", icon: "arrow.counterclockwise")
        case .preview:
            orbitAngle = 0
            cameraZ = Self.defaultCameraZ
            updatePreviewCamera()
            galleryRoot.move(to: Transform(), relativeTo: galleryRoot.parent, duration: 0.6, timingFunction: .easeInOut)
            arrangePreviewGallery()
            status = Status(message: "Gallery rebuilt. Tap a podium or a card to focus it.", icon: "arrow.counterclockwise")
        }
    }

    func select(_ id: UUID) {
        selectedID = id
        guard let memory = memories.first(where: { $0.id == id }) else { return }
        switch mode {
        case .preview:
            focusPreview(on: id)
            status = Status(message: memory.displayTitle + (memory.locationString.map { "  ·  📍 \($0)" } ?? ""), icon: "sparkles")
        case .augmented:
            status = placedIDs.contains(id)
                ? Status(message: "“\(memory.displayTitle)” is in the room — tap the floor to move it.", icon: "hand.tap")
                : Status(message: "Tap the floor to raise “\(memory.displayTitle)”.", icon: "hand.tap")
        }
    }

    func remove(_ id: UUID) {
        podiums.removeValue(forKey: id)?.removeFromParent()
        placedIDs.remove(id)
        if let memory = memories.first(where: { $0.id == id }) {
            status = Status(message: "Removed “\(memory.displayTitle)” from the room.", icon: "trash")
        }
    }

    // MARK: - AR session

    private func startAR() {
        arView.session.delegate = self
        configuration = makeConfiguration(detectionImages: [])
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        addCoachingOverlay()

        locationManager.start()
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.placeGPSMemoriesIfReady() }
            }
            .store(in: &cancellables)

        loadDetectionImages()
    }

    private func makeConfiguration(detectionImages: Set<ARReferenceImage>) -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        // -Z points to true north, +X to east: lets GPS bearings map straight into the room.
        config.worldAlignment = .gravityAndHeading
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        if !detectionImages.isEmpty {
            config.detectionImages = detectionImages
            config.maximumNumberOfTrackedImages = 1
        }
        return config
    }

    private func addCoachingOverlay() {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView.session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = true
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.frame = arView.bounds
        arView.addSubview(overlay)
    }

    /// Memory photos double as AR markers: point the iPad at a printed photo to find its memory.
    /// Low-detail photos are rejected by ARKit, so each one is validated before use.
    private func loadDetectionImages() {
        let candidates: [ARReferenceImage] = memories.compactMap { memory in
            guard let cgImage = memory.image?.preparedForMemory(maxDimension: 640).cgImage else { return nil }
            let reference = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
            reference.name = memory.id.uuidString
            return reference
        }
        guard !candidates.isEmpty else { return }

        Task { [weak self] in
            var valid: Set<ARReferenceImage> = []
            for reference in candidates {
                if (try? await reference.validate()) != nil {
                    valid.insert(reference)
                }
            }
            guard let self, self.isRunning, !valid.isEmpty else { return }
            self.configuration = self.makeConfiguration(detectionImages: valid)
            self.arView.session.run(self.configuration)
        }
    }

    private func registerFloor(_ plane: ARPlaneAnchor) {
        guard plane.alignment == .horizontal else { return }
        let planeY = plane.transform.translationVector.y
        let cameraY = arView.cameraTransform.translation.y
        // Table tops are ignored: the floor is a horizontal surface well below the iPad.
        let looksLikeFloor = plane.classification == .floor || cameraY - planeY > 0.8
        guard looksLikeFloor else { return }
        if floorY == nil || planeY < floorY! {
            floorY = planeY
        }
        placeGPSMemoriesIfReady()
    }

    // MARK: - GPS placement

    /// Places every pinned memory around the user in the real compass direction of where it happened.
    private func placeGPSMemoriesIfReady() {
        guard mode == .augmented, isRunning, !hasPlacedGPSMemories, isTrackingNormal,
              standTemplate != nil,
              let floorY,
              let location = locationManager.location,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy < 100 else { return }

        let pinned = memories.filter { $0.coordinate != nil && !placedIDs.contains($0.id) }
        hasPlacedGPSMemories = true
        guard !pinned.isEmpty else { return }

        let camera = arView.cameraTransform.translation
        let origin = SIMD3<Float>(camera.x, floorY, camera.z)
        var usedSpots: [SIMD3<Float>] = []

        for memory in pinned {
            guard let coordinate = memory.coordinate else { continue }
            let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = location.distance(from: target)
            let bearing = location.coordinate.bearing(to: coordinate)
            let direction = SIMD3<Float>(Float(sin(bearing)), 0, -Float(cos(bearing)))

            var radius = Self.walkableRadius(forDistance: distance)
            var spot = origin + direction * radius
            // Push podiums that would collide further out along the same bearing.
            while usedSpots.contains(where: { simd_distance($0, spot) < 1.2 }) {
                radius += 1.3
                spot = origin + direction * radius
            }
            usedSpots.append(spot)

            placePodium(for: memory, at: spot, facing: origin, caption: Self.distanceCaption(distance: distance, bearing: bearing))
        }

        let noun = pinned.count == 1 ? "memory" : "memories"
        status = Status(message: "Placed \(pinned.count) \(noun) around you, pointing to where they happened. Walk up to read them.", icon: "location.north.line.fill")
        selectNextUnplaced()
    }

    /// Real-world distance → a walkable distance in the room: 1:1 up close, then
    /// compressed logarithmically so even a memory in another city stays within ~8 m.
    static func walkableRadius(forDistance distance: CLLocationDistance) -> Float {
        if distance <= 3 { return Float(max(distance, 1.6)) }
        return Float(min(3 + log10(distance / 3) * 1.4, 8))
    }

    static func distanceCaption(distance: CLLocationDistance, bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let degrees = (bearing.toDegrees() + 360).truncatingRemainder(dividingBy: 360)
        let compass = directions[Int((degrees + 22.5) / 45) % 8]
        let formatted = distance < 1000
            ? "\(Int(distance.rounded())) m"
            : String(format: distance < 100_000 ? "%.1f km" : "%.0f km", distance / 1000)
        return "\(formatted) away · \(compass)"
    }

    // MARK: - Tap handling

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: arView)

        // Tapping a podium selects its memory.
        if let entity = arView.entity(at: point), let id = memoryID(for: entity) {
            select(id)
            if mode == .augmented, let memory = memories.first(where: { $0.id == id }) {
                status = Status(message: "“\(memory.displayTitle)” — drag to move, pinch to resize, twist to turn.", icon: "hand.draw")
            }
            return
        }

        guard mode == .augmented else { return }
        
        guard standTemplate != nil else {
            status = Status(message: "Preparing the podiums… try again in a moment.", icon: "hourglass")
            return
        }
        guard let memory = selectedMemory else {
            status = Status(message: "Pick a memory below, then tap the floor.", icon: "hand.tap")
            return
        }
        guard let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first else {
            status = Status(message: "No floor found there yet — keep scanning slowly.", icon: "viewfinder", isError: true)
            return
        }

        let position = result.worldTransform.translationVector
        let liveLocation = locationManager.location.map {
            String(format: "%.4f, %.4f", $0.coordinate.latitude, $0.coordinate.longitude)
        }
        placePodium(for: memory, at: position, facing: arView.cameraTransform.translation, locationOverride: memory.locationString ?? liveLocation)
        status = Status(message: "Placed “\(memory.displayTitle)”. Walk around it!", icon: "checkmark.circle")
        selectNextUnplaced()
    }

    private func selectNextUnplaced() {
        if let next = memories.first(where: { !placedIDs.contains($0.id) }) {
            selectedID = next.id
        }
    }

    private func memoryID(for entity: Entity) -> UUID? {
        var current: Entity? = entity
        while let candidate = current {
            if let id = UUID(uuidString: candidate.name), podiums[id] != nil { return id }
            current = candidate.parent
        }
        return nil
    }

    // MARK: - Image detection

    private func placeMemory(from imageAnchor: ARImageAnchor) {
        guard let name = imageAnchor.referenceImage.name,
              let id = UUID(uuidString: name),
              !placedIDs.contains(id),
              standTemplate != nil,
              let memory = memories.first(where: { $0.id == id }) else { return }
        placePodium(
            for: memory,
            at: imageAnchor.transform.translationVector,
            facing: arView.cameraTransform.translation,
            scale: 0.2,
            caption: "Found from your photo"
        )
        status = Status(message: "Recognised “\(memory.displayTitle)” from its photo — here's a miniature.", icon: "photo.badge.checkmark")
    }

    // MARK: - Podiums

    private func placePodium(
        for memory: MemoryItem,
        at position: SIMD3<Float>,
        facing target: SIMD3<Float>,
        scale: Float = 1,
        caption: String? = nil,
        locationOverride: String? = nil
    ) {
        podiums.removeValue(forKey: memory.id)?.removeFromParent()

        let podium = makePodium(for: memory, caption: caption, locationString: locationOverride ?? memory.locationString)
        // The podium's front is +Z; turn it to face the viewer.
        let yaw = atan2(target.x - position.x, target.z - position.z)
        let finalTransform = Transform(scale: SIMD3(repeating: scale), rotation: simd_quatf(angle: yaw, axis: [0, 1, 0]), translation: .zero)
        podium.transform = Transform(scale: SIMD3(repeating: scale * 0.01), rotation: finalTransform.rotation, translation: .zero)

        let container: Entity
        switch mode {
        case .augmented:
            let anchor = AnchorEntity(world: position)
            arView.scene.addAnchor(anchor)
            container = anchor
        case .preview:
            container = Entity()
            container.position = position
            galleryRoot.addChild(container)
        }
        container.addChild(podium)
        podium.move(to: finalTransform, relativeTo: container, duration: 0.7, timingFunction: .easeOut)

        if mode == .augmented {
            arView.installGestures([.translation, .rotation, .scale], for: podium)
        }

        podiums[memory.id] = container
        placedIDs.insert(memory.id)
    }

    private func makePodium(for memory: MemoryItem, caption: String?, locationString: String?) -> ModelEntity {
        let root = ModelEntity()
        root.name = memory.id.uuidString
        if let standTemplate {
            root.addChild(standTemplate.clone(recursive: true))
        }

        if let texture = texture(key: "placard-\(memory.id)-\(caption ?? "")-\(locationString ?? "")", content: {
            DescriptionContainerView(title: memory.displayTitle, description: memory.body, locationString: locationString, caption: caption)
        }) {
            let placard = ModelEntity(mesh: .generatePlane(width: 0.5, depth: 0.3), materials: [Self.paperMaterial(texture)])
            placard.transform = Transform(pitch: .pi / 5.6)
            placard.position = [0.023, 0.995, 0.225]
            root.addChild(placard)
        }

        if let texture = texture(key: "photo-\(memory.id)", content: {
            ImageContainerView(uiImage: memory.image)
        }) {
            let photo = ModelEntity(mesh: .generatePlane(width: 0.72, depth: 0.96), materials: [Self.paperMaterial(texture)])
            photo.transform = Transform(pitch: .pi / 2)
            photo.position = [0.023, 1.595, -0.208]
            root.addChild(photo)
        }

        // One collision box around the whole podium so tap-to-select and the move/rotate/scale gestures hit it.
        let bounds = root.visualBounds(relativeTo: root)
        root.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: bounds.extents).offsetBy(translation: bounds.center)])
        return root
    }

    /// SwiftUI → texture, cached per memory so placing, moving or re-placing never re-renders.
    private func texture<Content: View>(key: String, @ViewBuilder content: () -> Content) -> TextureResource? {
        if let cached = textureCache[key] { return cached }
        let renderer = ImageRenderer(content: content())
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else { return nil }

        let options = TextureResource.CreateOptions(semantic: .color)
        let texture: TextureResource?
        if #available(iOS 18.0, *) {
            texture = try? TextureResource(image: cgImage, options: options)
        } else {
            texture = try? TextureResource.generate(from: cgImage, options: options)
        }
        textureCache[key] = texture
        return texture
    }

    /// Unlit so placards stay crisp and readable in dim rooms.
    private static func paperMaterial(_ texture: TextureResource) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        return material
    }

    // MARK: - Preview gallery (Simulator / no AR)

    private func buildPreviewGallery() {
        arView.environment.background = .color(UIColor(red: 0.05, green: 0.06, blue: 0.11, alpha: 1))

        let world = AnchorEntity(world: .zero)
        world.addChild(galleryRoot)

        let floorMaterial = SimpleMaterial(color: UIColor(red: 0.13, green: 0.14, blue: 0.22, alpha: 1), roughness: 0.85, isMetallic: false)
        let floor = ModelEntity(mesh: .generatePlane(width: 40, depth: 40), materials: [floorMaterial])
        galleryRoot.addChild(floor)

        let keyLight = DirectionalLight()
        keyLight.light.intensity = 2600
        keyLight.look(at: [0, 1, -3], from: [2.5, 5, 3], relativeTo: nil)
        world.addChild(keyLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = 900
        fillLight.look(at: [0, 1, -3], from: [-3, 3, 2], relativeTo: nil)
        world.addChild(fillLight)

        previewCamera.camera.fieldOfViewInDegrees = 55
        world.addChild(previewCamera)
        arView.scene.addAnchor(world)

        arView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        arView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:))))

        arrangePreviewGallery()
        updatePreviewCamera()
        status = Status(message: "AR isn't available here — enjoy a 3D preview. Drag to look around, pinch to zoom.", icon: "cube.transparent")
    }

    /// Lays the podiums out on an arc in front of the viewer, all facing the centre,
    /// about 2 m apart so neighbouring podiums never overlap.
    private func arrangePreviewGallery() {
        let count = memories.count
        let spacing: Float = 2.0
        galleryRadius = max(4, spacing * Float(max(count - 1, 0)) / 2.4)
        let step = spacing / galleryRadius
        
        for (index, memory) in memories.enumerated() {
            let angle = (Float(index) - Float(count - 1) / 2) * step
            previewAngles[memory.id] = angle
            let position = SIMD3<Float>(sin(angle) * galleryRadius, 0, -cos(angle) * galleryRadius)
            placePodium(for: memory, at: position, facing: .zero)
        }
    }
    
    private func focusPreview(on id: UUID) {
        guard let angle = previewAngles[id], podiums[id] != nil else { return }
        orbitAngle = angle
        galleryRoot.move(
            to: Transform(scale: .one, rotation: simd_quatf(angle: orbitAngle, axis: [0, 1, 0]), translation: .zero),
            relativeTo: galleryRoot.parent,
            duration: 0.7,
            timingFunction: .easeInOut
        )
    }

    private func updatePreviewCamera() {
        previewCamera.look(at: [0, 1.2, -galleryRadius], from: [0, 1.6, cameraZ], relativeTo: nil)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            gestureStartAngle = orbitAngle
        case .changed:
            // Keep at least one podium in view: never orbit past the ends of the arc.
            let angles = previewAngles.values
            let limit = (min: (angles.min() ?? 0) - 0.35, max: (angles.max() ?? 0) + 0.35)
            let proposed = gestureStartAngle - Float(gesture.translation(in: arView).x) * 0.0022
            orbitAngle = min(max(proposed, limit.min), limit.max)
            galleryRoot.orientation = simd_quatf(angle: orbitAngle, axis: [0, 1, 0])
        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            gestureStartCameraZ = cameraZ
        case .changed:
            let zoomed = gestureStartCameraZ - (Float(gesture.scale) - 1) * 2.5
            cameraZ = min(max(zoomed, -galleryRadius + 2.2), 4.5)
            updatePreviewCamera()
        default:
            break
        }
    }
}

// MARK: - ARSessionDelegate

extension MuseumController: @preconcurrency ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor {
                registerFloor(plane)
            } else if let imageAnchor = anchor as? ARImageAnchor {
                placeMemory(from: imageAnchor)
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard floorY == nil else { return }
        for case let plane as ARPlaneAnchor in anchors {
            registerFloor(plane)
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            let wasNormal = isTrackingNormal
            isTrackingNormal = true
            if !wasNormal && placedIDs.isEmpty {
                let pinnedCount = memories.filter { $0.coordinate != nil }.count
                status = pinnedCount > 0
                    ? Status(message: "Looking for the floor and your GPS position… or tap the floor to place a memory.", icon: "location.magnifyingglass")
                    : Status(message: "Tap the floor to raise “\(selectedMemory?.displayTitle ?? "your memory")”.", icon: "hand.tap")
            }
            placeGPSMemoriesIfReady()
        case .limited(.excessiveMotion):
            status = Status(message: "Slow down a little…", icon: "tortoise")
        case .limited(.insufficientFeatures):
            status = Status(message: "Point at a textured, well-lit floor.", icon: "lightbulb")
        case .limited:
            status = Status(message: "Warming up AR…", icon: "viewfinder")
        case .notAvailable:
            status = Status(message: "Tracking isn't available right now.", icon: "exclamationmark.triangle", isError: true)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        if let arError = error as? ARError, arError.code == .invalidReferenceImage {
            // A photo was too plain to track — carry on without photo detection.
            configuration = makeConfiguration(detectionImages: [])
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            return
        }
        status = Status(message: "AR stopped: \(error.localizedDescription)", icon: "exclamationmark.triangle", isError: true)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        status = Status(message: "AR paused.", icon: "pause.circle")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        status = Status(message: "Back in the museum. Tap Reset if things drifted.", icon: "play.circle")
    }
}

// MARK: - ARView Container

struct ARViewContainer: UIViewRepresentable {
    let arView: ARView

    func makeUIView(context: Context) -> ARView { arView }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - Math helpers

extension Double {
    func toRadians() -> Double { self * .pi / 180.0 }
    func toDegrees() -> Double { self * 180.0 / .pi }
}

extension CLLocationCoordinate2D {
    /// Initial great-circle bearing to `other`, in radians clockwise from true north.
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude.toRadians()
        let lat2 = other.latitude.toRadians()
        let dLon = (other.longitude - longitude).toRadians()
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x)
    }
}

extension simd_float4x4 {
    var translationVector: SIMD3<Float> {
        SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }
}

// MARK: - Podium model

/// Loads the museum stand once, asynchronously, and shares it between museum visits.
@MainActor
enum PodiumLibrary {
    private static var cached: Entity?
    private static var loading: Task<Entity, Never>?
    
    static func template() async -> Entity {
        if let cached { return cached }
        if let loading { return await loading.value }
        let task = Task<Entity, Never> {
            let entity = await load()
            cached = entity
            return entity
        }
        loading = task
        return await task.value
    }
    
    private static func load() async -> Entity {
        if #available(iOS 18.0, *) {
            if let model = try? await Entity(named: "chosen-stand") { return model }
        } else if let model = loadSynchronously() {
            return model
        }
        print("⚠️ chosen-stand.usdz not found — using a procedural podium")
        return makeFallbackStand()
    }
    
    /// iOS 17 has no async model initialiser.
    private static func loadSynchronously() -> Entity? {
        try? Entity.loadModel(named: "chosen-stand")
    }
    
    /// A simple marble plinth with a backboard, matching the placard/photo positions of the real model.
    private static func makeFallbackStand() -> Entity {
        let root = Entity()
        let marble = SimpleMaterial(color: UIColor(white: 0.95, alpha: 1), roughness: 0.35, isMetallic: false)
        
        let column = ModelEntity(mesh: .generateBox(width: 0.56, height: 0.92, depth: 0.5, cornerRadius: 0.02), materials: [marble])
        column.position = [0.023, 0.46, 0.05]
        
        let backboard = ModelEntity(mesh: .generateBox(width: 0.82, height: 2.1, depth: 0.05, cornerRadius: 0.01), materials: [marble])
        backboard.position = [0.023, 1.05, -0.24]
        
        root.addChild(column)
        root.addChild(backboard)
        return root
    }
}
