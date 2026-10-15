import SwiftUI

/// Which memories to bring into the AR museum.
enum MuseumScope: Identifiable, Hashable {
    case all
    case single(MemoryItem.ID)

    var id: String {
        switch self {
        case .all: return "all"
        case .single(let id): return id.uuidString
        }
    }
}

struct HomeScreenView: View {
    @StateObject private var vm = HomeScreenViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var museumScope: MuseumScope?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack {
                detail
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.primaryColor)
        .preferredColorScheme(.light)
        .environmentObject(locationManager)
        .fullScreenCover(item: $museumScope) { scope in
            MuseumView(memories: memories(for: scope))
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
                            museumScope = .single(item.id)
                        } label: {
                            Label("View in AR", systemImage: "arkit")
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
        .listStyle(.sidebar)
        .overlay {
            if vm.memoryItems.isEmpty {
                ContentUnavailableView {
                    Label("No Memories Yet", systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text("Capture a moment, pin where it happened, then walk through it in AR.")
                } actions: {
                    Button("New Memory") { vm.addMemoryItem() }
                        .buttonStyle(.borderedProminent)
                }
            } else if vm.filteredItems.isEmpty {
                ContentUnavailableView.search(text: vm.searchText)
            }
        }
        .searchable(text: $vm.searchText, placement: .sidebar, prompt: "Search memories")
        .navigationTitle("LUME")
        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
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
        .safeAreaInset(edge: .bottom) {
            enterMuseumButton
        }
    }

    private var enterMuseumButton: some View {
        let pinnedCount = vm.memoryItems.filter { $0.coordinate != nil }.count
        return Button {
            museumScope = .all
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter Memory Museum")
                        .font(.system(.headline, design: .rounded))
                    Text("\(vm.memoryItems.count) memories · \(pinnedCount) pinned by GPS")
                        .font(.caption)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.primaryColor, Color(hex: 0x8B5CF6)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Color.primaryColor.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(vm.memoryItems.isEmpty)
        .opacity(vm.memoryItems.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = vm.selectedID, let memoryItem = vm.binding(for: id) {
            MemoryView(
                memoryItem: memoryItem,
                onViewInAR: { museumScope = .single(id) },
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
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func memories(for scope: MuseumScope) -> [MemoryItem] {
        switch scope {
        case .all:
            return vm.memoryItems
        case .single(let id):
            return vm.memoryItems.filter { $0.id == id }
        }
    }
}
