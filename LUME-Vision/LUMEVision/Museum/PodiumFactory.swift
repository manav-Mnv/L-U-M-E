import SwiftUI
import RealityKit

/// Marks the root entity of a memory podium so gestures can find which memory was touched.
struct PodiumComponent: Component {
    let memoryID: UUID
}

/// Builds the museum podiums shared by the tabletop and immersive museums.
@MainActor
enum PodiumFactory {
    private static var cachedTemplate: Entity?
    private static var loading: Task<Entity, Never>?
    private static var textures: [String: TextureResource] = [:]

    /// The `chosen-stand` model, loaded once and shared.
    static func template() async -> Entity {
        if let cachedTemplate { return cachedTemplate }
        if let loading { return await loading.value }
        let task = Task<Entity, Never> {
            let entity = (try? await Entity(named: "chosen-stand")) ?? makeFallbackStand()
            cachedTemplate = entity
            return entity
        }
        loading = task
        return await task.value
    }

    /// A life-size podium (about 2.1 m tall) whose front faces +Z. Scale it down for the tabletop.
    static func makePodium(for memory: MemoryItem, caption: String?, template: Entity) -> Entity {
        let root = Entity()
        root.name = memory.id.uuidString
        root.components.set(PodiumComponent(memoryID: memory.id))
        root.addChild(template.clone(recursive: true))

        let placardKey = "placard-\(memory.id)-\(memory.title.hashValue)-\(memory.body.hashValue)-\(memory.locationString ?? "")-\(caption ?? "")"
        if let texture = texture(key: placardKey, content: {
            DescriptionContainerView(title: memory.displayTitle, description: memory.body, locationString: memory.locationString, caption: caption)
        }) {
            let placard = ModelEntity(mesh: .generatePlane(width: 0.5, depth: 0.3), materials: [paperMaterial(texture)])
            placard.transform = Transform(pitch: .pi / 5.6)
            placard.position = [0.023, 0.995, 0.225]
            root.addChild(placard)
        }

        let photoKey = "photo-\(memory.id)-\(memory.image.map { ObjectIdentifier($0).hashValue } ?? 0)"
        if let texture = texture(key: photoKey, content: { ImageContainerView(uiImage: memory.image) }) {
            let photo = ModelEntity(mesh: .generatePlane(width: 0.72, depth: 0.96), materials: [paperMaterial(texture)])
            photo.transform = Transform(pitch: .pi / 2)
            photo.position = [0.023, 1.595, -0.208]
            root.addChild(photo)
        }

        // One collision box around the whole podium: it receives gaze, pinches and drags,
        // and glows softly while you look at it.
        let bounds = root.visualBounds(relativeTo: root)
        root.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: bounds.extents).offsetBy(translation: bounds.center)]))
        root.components.set(InputTargetComponent())
        root.components.set(HoverEffectComponent())
        return root
    }

    /// The podium (and its memory) that contains `entity`, if any.
    static func podium(containing entity: Entity) -> (entity: Entity, memoryID: UUID)? {
        var current: Entity? = entity
        while let candidate = current {
            if let component = candidate.components[PodiumComponent.self] {
                return (candidate, component.memoryID)
            }
            current = candidate.parent
        }
        return nil
    }

    // MARK: - Textures

    /// SwiftUI → texture, cached so podiums can be rebuilt or re-placed cheaply.
    private static func texture<Content: View>(key: String, @ViewBuilder content: () -> Content) -> TextureResource? {
        if let cached = textures[key] { return cached }
        let renderer = ImageRenderer(content: content())
        renderer.scale = 1
        guard let cgImage = renderer.cgImage,
              let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color)) else { return nil }
        textures[key] = texture
        return texture
    }

    /// Unlit so placards stay crisp and readable in any room.
    private static func paperMaterial(_ texture: TextureResource) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        return material
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
