import SwiftUI

/// The main journal window: memories in the sidebar, the editor on the right,
/// and museum controls in an ornament below the window.
struct JournalView: View {
    @EnvironmentObject private var vm: HomeScreenViewModel
    @Environment(MuseumSession.self) private var museum
    @Environment(\.openWindow) private var openWindow
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack {
                detail
            }
        }
        .environmentObject(locationManager)
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            MuseumOrnament()
                .padding(.top, 20)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $vm.selectedID) {
            ForEach(vm.filteredItems) { item in
                MemoryCard(memoryItem: item)
                    .tag(item.id)
                    .contextMenu {
                        Button {
                            showInTabletop(item.id)
                        } label: {
                            Label("Show in Tabletop Museum", systemImage: "cube.transparent")
                        }
                        Button {
                            vm.duplicateMemoryItem(id: item.id)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        Divider()
                        Button(role: .destructive) {
                            vm.deleteMemoryItem(id: item.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            vm.deleteMemoryItem(id: item.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .overlay {
            if vm.memoryItems.isEmpty {
                ContentUnavailableView {
                    Label("No Memories Yet", systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text("Capture a moment, pin where it happened, then walk through it.")
                } actions: {
                    Button("New Memory") { vm.addMemoryItem() }
                }
            } else if vm.filteredItems.isEmpty {
                ContentUnavailableView.search(text: vm.searchText)
            }
        }
        .searchable(text: $vm.searchText, prompt: "Search memories")
        .navigationTitle("LUME")
        .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    vm.addMemoryItem()
                } label: {
                    Label("New Memory", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = vm.selectedID, let memoryItem = vm.binding(for: id) {
            VisionMemoryEditor(
                memoryItem: memoryItem,
                onShowInMuseum: { showInTabletop(id) },
                onDelete: { vm.deleteMemoryItem(id: id) }
            )
            .id(id)
        } else {
            ContentUnavailableView {
                Label("Choose a Memory", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("Select a memory from the sidebar, or create a new one.")
            } actions: {
                Button {
                    vm.addMemoryItem()
                } label: {
                    Label("New Memory", systemImage: "plus")
                }
            }
        }
    }

    private func showInTabletop(_ id: MemoryItem.ID) {
        museum.focusedMemoryID = id
        openWindow(id: SceneID.tabletop)
    }
}
