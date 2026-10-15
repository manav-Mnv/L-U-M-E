import SwiftUI

@main
struct LUMEVisionApp: App {
    /// One journal shared by every window and the immersive space.
    @StateObject private var journal = HomeScreenViewModel()
    @State private var museum = MuseumSession()

    init() {
        PodiumComponent.registerComponent()
    }

    var body: some Scene {
        WindowGroup(id: SceneID.journal) {
            JournalRootView()
                .environmentObject(journal)
                .environment(museum)
        }
        .defaultSize(width: 1280, height: 860)

        WindowGroup(id: SceneID.tabletop) {
            TabletopMuseumView()
                .environmentObject(journal)
                .environment(museum)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.3, height: 0.7, depth: 1.0, in: .meters)

        ImmersiveSpace(id: SceneID.immersiveMuseum) {
            ImmersiveMuseumView()
                .environmentObject(journal)
                .environment(museum)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

enum SceneID {
    static let journal = "journal"
    static let tabletop = "tabletop-museum"
    static let immersiveMuseum = "immersive-museum"
}
