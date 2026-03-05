import SwiftUI
import RealityKit
import ARKit
import CoreLocation

struct ARMuseumView: View {
    @Environment(\.dismiss) var dismiss
    var memories: [MemoryItem]
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    @State private var currentMemoryIndex: Int = 0
    @State private var modelPlacedCount: Int = 0
    @State private var infoMessage: String = "Tap on a flat surface or wait for GPS to locate memories."
    @State private var isError: Bool = false
    @State private var resetTrigger: Int = 0
    
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                memories: memories,
                currentIndex: $currentMemoryIndex,
                resetTrigger: $resetTrigger,
                locationManager: locationManager,
                onMessageUpdate: { message, error in
                    withAnimation {
                        infoMessage = message
                        isError = error
                    }
                }
            )
            .ignoresSafeArea()
            
            // Top Buttons
            VStack {
                HStack {
                    Button {
                        columnVisibility = .doubleColumn
                        dismiss()
                    } label: {
                        Text("Dismiss")
                            .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(100)
                            .shadow(radius: 4)
                    }
                    .padding(.top, 16)
                    .padding(.leading, 24)
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            resetTrigger += 1
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .padding(14)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                }
                Spacer()
            }
            
            // Bottom Information Overlay
            Text(infoMessage)
                .multilineTextAlignment(.center)
                .font(.headline)
                .foregroundColor(isError ? .red : .primary)
                .padding()
                .frame(width: 320)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - ARView Container
struct ARViewContainer: UIViewRepresentable {
    var memories: [MemoryItem]
    @Binding var currentIndex: Int
    @Binding var resetTrigger: Int
    @ObservedObject var locationManager: LocationManager
    var onMessageUpdate: @MainActor (String, Bool) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        
        guard ARWorldTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                self.onMessageUpdate("AR is not supported on this device.", true)
            }
            return arView
        }
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        var referenceImages: Set<ARReferenceImage> = []
        for (index, memory) in memories.enumerated() {
            if let image = memory.image, let cgImage = image.cgImage {
                let refImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
                refImage.name = "memory_\(index)"
                referenceImages.insert(refImage)
            }
        }
        
        if !referenceImages.isEmpty {
            config.detectionImages = referenceImages
            config.maximumNumberOfTrackedImages = referenceImages.count
        }
        
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        context.coordinator.placeMemoriesFromLocation(locationManager: locationManager)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        context.coordinator.arView = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if context.coordinator.lastResetTrigger != resetTrigger {
            context.coordinator.lastResetTrigger = resetTrigger
            
            uiView.scene.anchors.removeAll()
            
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            
            var referenceImages: Set<ARReferenceImage> = []
            for (index, memory) in memories.enumerated() {
                if let image = memory.image, let cgImage = image.cgImage {
                    let refImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
                    refImage.name = "memory_\(index)"
                    referenceImages.insert(refImage)
                }
            }
            
            if !referenceImages.isEmpty {
                config.detectionImages = referenceImages
                config.maximumNumberOfTrackedImages = referenceImages.count
            }
            
            uiView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            context.coordinator.hasPlacedGeoMemories = false
            context.coordinator.placeMemoriesFromLocation(locationManager: locationManager)
            
            DispatchQueue.main.async {
                self.currentIndex = 0
                self.onMessageUpdate("Session reset. Scanning GPS...", false)
            }
        }
        
        // Listen for GPS lock to drop memories
        if context.coordinator.hasPlacedGeoMemories == false && locationManager.location != nil && locationManager.heading != nil {
            context.coordinator.placeMemoriesFromLocation(locationManager: locationManager)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARViewContainer
        var arView: ARView?
        var memoryStand: ModelEntity?
        var lastResetTrigger: Int = 0
        var hasPlacedGeoMemories: Bool = false
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
            super.init()
            if let model = try? Entity.loadModel(named: "chosen-stand") {
                memoryStand = model
            }
        }
        
        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            Task { @MainActor in
                guard let arView = self.arView else { return }
                for anchor in anchors {
                    if let imageAnchor = anchor as? ARImageAnchor, let name = imageAnchor.referenceImage.name {
                        if name.hasPrefix("memory_"), let indexStr = name.split(separator: "_").last, let index = Int(indexStr) {
                            
                            let memoryAnchor = AnchorEntity(anchor: imageAnchor)
                            
                            guard let standTemplate = self.memoryStand else { continue }
                            let newStand = standTemplate.clone(recursive: true)
                            
                            if let descModel = self.createDescriptionModel(index: index) {
                                memoryAnchor.addChild(descModel)
                            }
                            if let imageModel = self.createImageModel(index: index) {
                                memoryAnchor.addChild(imageModel)
                            }
                            
                            memoryAnchor.addChild(newStand)
                            arView.scene.addAnchor(memoryAnchor)
                            
                            self.parent.onMessageUpdate("Found memory image: \(self.parent.memories[index].title)", false)
                        }
                    }
                }
            }
        }
        
        func placeMemoriesFromLocation(locationManager: LocationManager) {
            guard !hasPlacedGeoMemories,
                  let arView = arView,
                  let userLocation = locationManager.location,
                  let heading = locationManager.heading else { return }
            
            hasPlacedGeoMemories = true
            var placedCount = 0
            
            for (index, memory) in parent.memories.enumerated() {
                if let targetLat = memory.latitude, let targetLon = memory.longitude {
                    let targetLocation = CLLocation(latitude: targetLat, longitude: targetLon)
                    
                    let distance = userLocation.distance(from: targetLocation)
                    
                    // Simple bearing calculation
                    let lat1 = userLocation.coordinate.latitude.toRadians()
                    let lon1 = userLocation.coordinate.longitude.toRadians()
                    let lat2 = targetLocation.coordinate.latitude.toRadians()
                    let lon2 = targetLocation.coordinate.longitude.toRadians()
                    
                    let dLon = lon2 - lon1
                    let y = sin(dLon) * cos(lat2)
                    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
                    let bearingRadians = atan2(y, x)
                    let bearingDegrees = bearingRadians.toDegrees()
                    
                    // Adjust bearing relative to true north
                    let trueHeading = heading.trueHeading
                    let angleDifferenceDegrees = bearingDegrees - trueHeading
                    let angleDifferenceRadians = angleDifferenceDegrees.toRadians()
                    
                    // Convert to local ARKit coordinate system (Z is negative forward, X is right)
                    let dx = distance * sin(angleDifferenceRadians)
                    let dz = -distance * cos(angleDifferenceRadians) // Negative because -Z is forward in ARKit
                    
                    // Cap distance for visibility (e.g. don't place more than 20 meters away visually)
                    let limitedDistance = min(distance, 5.0) 
                    let scaleRatio = limitedDistance / max(distance, 1.0)
                    let visualDx = Float(dx * scaleRatio)
                    let visualDz = Float(dz * scaleRatio)
                    
                    let transform = Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: [0,1,0]), translation: [visualDx, 0, visualDz])
                    let memoryAnchor = AnchorEntity(world: transform.matrix)
                    
                    guard let standTemplate = memoryStand else { continue }
                    let newStand = standTemplate.clone(recursive: true)
                    
                    Task { @MainActor in
                        if let descModel = self.createDescriptionModel(index: index) {
                            memoryAnchor.addChild(descModel)
                        }
                        if let imageModel = self.createImageModel(index: index) {
                            memoryAnchor.addChild(imageModel)
                        }
                    }
                    
                    memoryAnchor.addChild(newStand)
                    arView.scene.addAnchor(memoryAnchor)
                    placedCount += 1
                }
            }
            
            if placedCount > 0 {
                DispatchQueue.main.async {
                    self.parent.onMessageUpdate("Placed \(placedCount) GPS memories.", false)
                }
            }
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            if parent.currentIndex >= parent.memories.count {
                parent.onMessageUpdate("You've placed all memories. Create more to continue.", true)
                return
            }
            
            let tapLocation = sender.location(in: arView)
            
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
            guard let firstResult = results.first else {
                parent.onMessageUpdate("No flat surface detected. Scan the floor more.", false)
                return
            }
            
            guard let standTemplate = memoryStand else {
                parent.onMessageUpdate("Error loading 3D stand.", true)
                return
            }
            
            let newStand = standTemplate.clone(recursive: true)
            let anchor = AnchorEntity(world: firstResult.worldTransform)
            
            let liveLocation = parent.locationManager.location?.coordinate
            
            if let descModel = createDescriptionModel(index: parent.currentIndex, liveLocation: liveLocation) {
                anchor.addChild(descModel)
            }
            if let imageModel = createImageModel(index: parent.currentIndex, liveLocation: liveLocation) {
                anchor.addChild(imageModel)
            }
            
            anchor.addChild(newStand)
            arView.scene.addAnchor(anchor)
            
            parent.currentIndex += 1
            let remaining = parent.memories.count - parent.currentIndex
            parent.onMessageUpdate("Placed! You can place \(remaining) more stands.", false)
        }
        
        // MARK: SwiftUI to RealityKit Renderers
        @MainActor
        private func createDescriptionModel(index: Int, liveLocation: CLLocationCoordinate2D? = nil) -> ModelEntity? {
            let memory = parent.memories[index]
            
            var locationString: String? = nil
            if let live = liveLocation {
                locationString = String(format: "%.4f, %.4f", live.latitude, live.longitude)
            } else if let lat = memory.latitude, let lon = memory.longitude {
                locationString = String(format: "%.4f, %.4f", lat, lon)
            }
            
            let descriptionView = DescriptionContainerView(title: memory.title, description: memory.body, locationString: locationString)
            let renderer = ImageRenderer(content: descriptionView)
            renderer.scale = UIScreen.main.scale
            
            guard let uiImage = renderer.uiImage,
                  let cgImage = uiImage.cgImage,
                  let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .normal)) else {
                return nil
            }
            
            let material = createPaperMaterial(with: texture)
            let mesh: MeshResource = .generatePlane(width: 0.5, depth: 0.3)
            let model = ModelEntity(mesh: mesh, materials: [material])
            
            model.transform = Transform(pitch: .pi/5.6)
            model.position = [0.023, 0.995, 0.225]
            return model
        }
        
        @MainActor
        private func createImageModel(index: Int, liveLocation: CLLocationCoordinate2D? = nil) -> ModelEntity? {
            let memory = parent.memories[index]
            
            var locationString: String? = nil
            if let live = liveLocation {
                locationString = String(format: "%.4f, %.4f", live.latitude, live.longitude)
            } else if let lat = memory.latitude, let lon = memory.longitude {
                locationString = String(format: "%.4f, %.4f", lat, lon)
            }
            
            let imageView = ImageContainerView(uiImage: memory.image, locationString: locationString)
            let renderer = ImageRenderer(content: imageView)
            renderer.scale = UIScreen.main.scale
            
            guard let uiImage = renderer.uiImage,
                  let cgImage = uiImage.cgImage,
                  let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .normal)) else {
                return nil
            }
            
            let material = createPaperMaterial(with: texture)
            let mesh: MeshResource = .generatePlane(width: 0.72, depth: 0.96)
            let model = ModelEntity(mesh: mesh, materials: [material])
            
            model.transform = Transform(pitch: .pi/2)
            model.position = [0.023, 1.595, -0.208]
            return model
        }
        
        private func createPaperMaterial(with texture: TextureResource) -> SimpleMaterial {
            var material = SimpleMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.metallic = .float(0)
            material.roughness = .float(1)
            return material
        }
    }
}

extension Double {
    func toRadians() -> Double { self * .pi / 180.0 }
    func toDegrees() -> Double { self * 180.0 / .pi }
}
