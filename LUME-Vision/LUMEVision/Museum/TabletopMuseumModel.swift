import SwiftUI
import RealityKit
import Observation

/// A miniature rotunda: podiums stand around a turntable, facing outward,
/// and the selected memory turns to the front.
@MainActor
@Observable
final class TabletopMuseumModel {
    /// Added to the volume's RealityView; its origin is the centre of the volume.
    let root = Entity()

    private(set) var selectedID: UUID?
    private(set) var isReady = false

    @ObservationIgnored private let turntable = Entity()
    @ObservationIgnored private let spotlight: ModelEntity
    @ObservationIgnored private var template: Entity?
    @ObservationIgnored private var podiums: [UUID: Entity] = [:]
    @ObservationIgnored private var angles: [UUID: Float] = [:]
    @ObservationIgnored private var signature: [String] = []
    @ObservationIgnored private var yaw: Float = 0
    @ObservationIgnored private var dragStartYaw: Float?

    /// Top of the base disc, just above the bottom of a 0.7 m tall volume.
    private let baseTop: Float = -0.3
    private let baseRadius: Float = 0.47

    init() {
        let base = ModelEntity(
            mesh: .generateCylinder(height: 0.024, radius: baseRadius),
            materials: [SimpleMaterial(color: UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1), roughness: 0.25, isMetallic: true)]
        )
        base.position.y = baseTop - 0.012
        // The base itself is grabbable, so a drag anywhere on the table spins it.
        base.components.set(CollisionComponent(shapes: [.generateBox(width: baseRadius * 2, height: 0.024, depth: baseRadius * 2)]))
        base.components.set(InputTargetComponent())

        let rim = ModelEntity(
            mesh: .generateCylinder(height: 0.006, radius: baseRadius + 0.012),
            materials: [UnlitMaterial(color: UIColor(red: 0.39, green: 0.4, blue: 0.95, alpha: 1))]
        )
        rim.position.y = baseTop - 0.02

        spotlight = ModelEntity(
            mesh: .generateCylinder(height: 0.002, radius: 0.1),
            materials: [UnlitMaterial(color: UIColor(red: 0.55, green: 0.56, blue: 1, alpha: 1))]
        )
        spotlight.isEnabled = false

        turntable.addChild(base)
        turntable.addChild(spotlight)
        root.addChild(rim)
        root.addChild(turntable)
    }

    func prepare() async {
        template = await PodiumFactory.template()
        isReady = true
    }

    /// Rebuilds the podiums when anything visible about the memories changed.
    func update(with memories: [MemoryItem]) {
        guard let template else { return }
        let newSignature = memories.map {
            "\($0.id)|\($0.title)|\($0.body)|\($0.locationString ?? "")|\($0.image.map { ObjectIdentifier($0).hashValue } ?? 0)"
        }
        guard newSignature != signature else { return }
        signature = newSignature

        for podium in podiums.values { podium.removeFromParent() }
        podiums.removeAll()
        angles.removeAll()

        let count = memories.count
        guard count > 0 else {
            spotlight.isEnabled = false
            selectedID = nil
            return
        }

        // Shrink podiums a little when there are many, so the ring never overcrowds.
        let scale: Float = count <= 10 ? 0.17 : 0.17 * 10 / Float(count)
        let radius: Float = count == 1 ? 0 : min(max(Float(count) * 0.2 * scale / 0.17 / (2 * .pi), 0.16), 0.36)

        for (index, memory) in memories.enumerated() {
            let angle = Float(index) / Float(count) * 2 * .pi
            angles[memory.id] = angle

            let container = Entity()
            container.position = [sin(angle) * radius, baseTop, cos(angle) * radius]
            container.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])

            let podium = PodiumFactory.makePodium(for: memory, caption: nil, template: template)
            podium.scale = SIMD3(repeating: scale)
            container.addChild(podium)
            turntable.addChild(container)
            podiums[memory.id] = container
        }

        if let selectedID, podiums[selectedID] != nil {
            select(selectedID, animated: false)
        } else if let first = memories.first {
            select(first.id, animated: false)
        }
    }

    /// Turns the turntable so `id` faces the viewer and lights the floor under it.
    func select(_ id: UUID, animated: Bool = true) {
        guard let angle = angles[id], let container = podiums[id] else { return }
        selectedID = id

        // Shortest way round to the front.
        var target = -angle
        while target - yaw > .pi { target -= 2 * .pi }
        while target - yaw < -.pi { target += 2 * .pi }
        yaw = target

        let transform = Transform(rotation: simd_quatf(angle: yaw, axis: [0, 1, 0]))
        if animated {
            turntable.move(to: transform, relativeTo: root, duration: 0.8, timingFunction: .easeInOut)
        } else {
            turntable.transform = transform
        }

        spotlight.isEnabled = true
        spotlight.position = [container.position.x, baseTop + 0.002, container.position.z]
    }

    func handleTap(on entity: Entity) {
        if let podium = PodiumFactory.podium(containing: entity) {
            select(podium.memoryID)
        }
    }

    func drag(by translation: CGFloat) {
        if dragStartYaw == nil { dragStartYaw = yaw }
        yaw = (dragStartYaw ?? 0) + Float(translation) * 0.006
        turntable.transform = Transform(rotation: simd_quatf(angle: yaw, axis: [0, 1, 0]))
    }

    func endDrag() {
        dragStartYaw = nil
        // Settle on whichever podium ended up nearest the front.
        let nearest = angles.min { lhs, rhs in
            angularDistance(lhs.value + yaw) < angularDistance(rhs.value + yaw)
        }
        if let nearest {
            select(nearest.key)
        }
    }

    private func angularDistance(_ angle: Float) -> Float {
        abs(atan2(sin(angle), cos(angle)))
    }
}
