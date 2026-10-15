import SwiftUI

/// Floating controls under the journal window: open the tabletop museum or walk into the life-size one.
struct MuseumOrnament: View {
    @EnvironmentObject private var vm: HomeScreenViewModel
    @Environment(MuseumSession.self) private var museum
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        HStack(spacing: 16) {
            Button {
                openWindow(id: SceneID.tabletop)
            } label: {
                Label("Tabletop Museum", systemImage: "cube.transparent")
            }

            Button {
                Task { await toggleImmersiveMuseum() }
            } label: {
                if museum.immersiveState == .open {
                    Label("Leave Museum", systemImage: "xmark.circle")
                } else {
                    Label("Walk Through Museum", systemImage: "figure.walk")
                }
            }
            .disabled(museum.immersiveState == .inTransition || vm.memoryItems.isEmpty)
        }
        .font(.title3)
        .padding(16)
        .glassBackgroundEffect()
    }

    private func toggleImmersiveMuseum() async {
        switch museum.immersiveState {
        case .open:
            museum.immersiveState = .inTransition
            await dismissImmersiveSpace()
            museum.immersiveState = .closed
        case .closed:
            museum.immersiveState = .inTransition
            switch await openImmersiveSpace(id: SceneID.immersiveMuseum) {
            case .opened:
                museum.immersiveState = .open
            default:
                museum.immersiveState = .closed
            }
        case .inTransition:
            break
        }
    }
}
