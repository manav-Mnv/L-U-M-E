import SwiftUI
import RealityKit

/// The tabletop museum volume: a miniature rotunda of memory podiums you can spin.
struct TabletopMuseumView: View {
    @EnvironmentObject private var vm: HomeScreenViewModel
    @Environment(MuseumSession.self) private var museum
    @State private var model = TabletopMuseumModel()
    @State private var rebuildTask: Task<Void, Never>?

    var body: some View {
        RealityView { content in
            content.add(model.root)
            await model.prepare()
            model.update(with: vm.memoryItems)
            if let focused = museum.focusedMemoryID {
                model.select(focused)
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    model.handleTap(on: value.entity)
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .targetedToAnyEntity()
                .onChanged { value in
                    model.drag(by: value.translation.width)
                }
                .onEnded { _ in
                    model.endDrag()
                }
        )
        .onChange(of: vm.memoryItems) { _, items in
            // Debounced so typing in the journal doesn't rebuild the table on every keystroke.
            rebuildTask?.cancel()
            rebuildTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                model.update(with: items)
            }
        }
        .onChange(of: museum.focusedMemoryID) { _, id in
            if let id { model.select(id) }
        }
        // Anchored to the front edge so the base disc never hides the panel.
        .ornament(attachmentAnchor: .scene(.bottomFront), contentAlignment: .top) {
            TabletopOrnament(model: model)
                .padding(.top, 24)
        }
    }
}

/// Memory picker and details floating under the volume.
private struct TabletopOrnament: View {
    let model: TabletopMuseumModel

    @EnvironmentObject private var vm: HomeScreenViewModel
    @Environment(MuseumSession.self) private var museum
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    private var selected: MemoryItem? {
        vm.memoryItems.first { $0.id == model.selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selected {
                HStack(alignment: .firstTextBaseline) {
                    Text(selected.displayTitle)
                        .font(.custom("KomorebiRegular", size: 34))
                    Spacer()
                    if let locationString = selected.locationString {
                        Label(locationString, systemImage: "mappin.and.ellipse")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(selected.body.isEmpty ? "A memory waiting for its story." : selected.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if !model.isReady {
                Label("Preparing the museum…", systemImage: "hourglass")
            } else {
                Label("Create a memory in the journal to fill the museum.", systemImage: "sparkles")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.memoryItems) { memory in
                        Button {
                            museum.focusedMemoryID = memory.id
                            model.select(memory.id)
                        } label: {
                            MemoryChip(memory: memory, isSelected: memory.id == model.selectedID)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Label("Drag the table to spin it · pinch a podium to bring it forward", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await openLifeSizeMuseum() }
                } label: {
                    Label("Walk Through Life-Size", systemImage: "figure.walk")
                }
                .disabled(museum.immersiveState != .closed)
            }
        }
        .padding(24)
        .frame(width: 720)
        .glassBackgroundEffect()
    }

    private func openLifeSizeMuseum() async {
        museum.immersiveState = .inTransition
        switch await openImmersiveSpace(id: SceneID.immersiveMuseum) {
        case .opened:
            museum.immersiveState = .open
        default:
            museum.immersiveState = .closed
        }
    }
}

/// A thumbnail + title button used in the museum pickers.
struct MemoryChip: View {
    let memory: MemoryItem
    let isSelected: Bool
    var isPlaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.primaryColor, Color(hex: 0x8B5CF6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    if let image = memory.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: 120, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isPlaced {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .padding(4)
                    }
                }
            Text(memory.displayTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.primaryColor.opacity(0.5) : Color.white.opacity(0.05))
        )
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18, style: .continuous))
        .hoverEffect()
    }
}
