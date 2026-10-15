import SwiftUI
import RealityKit

/// The life-size memory museum around the user (mixed immersion: your room stays visible).
struct ImmersiveMuseumView: View {
    @EnvironmentObject private var vm: HomeScreenViewModel
    @Environment(MuseumSession.self) private var museum
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var model = ImmersiveMuseumModel()

    var body: some View {
        RealityView { content, attachments in
            content.add(model.root)
            if let panel = attachments.entity(for: "controls") {
                // Floating at a comfortable reading height, a little under a metre in front of you.
                panel.position = [0, 1.05, -0.9]
                model.root.addChild(panel)
            }
        } update: { _, attachments in
            model.updateInfoCard(attachments.entity(for: "info"))
        } attachments: {
            Attachment(id: "controls") {
                ImmersiveControlPanel(model: model) {
                    Task { await leave() }
                }
            }
            Attachment(id: "info") {
                if let memory = model.inspectedMemory {
                    MemoryInfoCard(
                        memory: memory,
                        caption: model.caption(for: memory.id),
                        onClose: { model.closeInfoCard() },
                        onRemove: { model.remove(memory.id) }
                    )
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let position = value.convert(value.location3D, from: .local, to: .scene)
                    model.handleTap(on: value.entity, at: position)
                }
        )
        .simultaneousGesture(
            DragGesture()
                .targetedToEntity(where: .has(PodiumComponent.self))
                .onChanged { value in
                    let position = value.convert(value.location3D, from: .local, to: .scene)
                    model.drag(value.entity, to: position)
                }
                .onEnded { _ in model.endDrag() }
        )
        .simultaneousGesture(
            RotateGesture3D(constrainedToAxis: .y)
                .targetedToEntity(where: .has(PodiumComponent.self))
                .onChanged { value in
                    let rotation = value.rotation
                    let sign: Double = rotation.axis.y >= 0 ? 1 : -1
                    model.rotate(value.entity, by: Float(rotation.angle.radians * sign))
                }
                .onEnded { _ in model.endRotation() }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .targetedToEntity(where: .has(PodiumComponent.self))
                .onChanged { value in
                    model.scale(value.entity, by: Float(value.magnification))
                }
                .onEnded { _ in model.endScale() }
        )
        .task {
            model.update(memories: vm.memoryItems)
            await model.start()
        }
        .onChange(of: vm.memoryItems) { _, items in
            model.update(memories: items)
        }
        .onDisappear {
            model.stop()
            museum.immersiveState = .closed
        }
    }

    private func leave() async {
        museum.immersiveState = .inTransition
        await dismissImmersiveSpace()
        museum.immersiveState = .closed
    }
}

/// The floating glass control panel inside the museum.
private struct ImmersiveControlPanel: View {
    let model: ImmersiveMuseumModel
    var onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Memory Museum")
                    .font(.custom("KomorebiRegular", size: 44))
                Spacer()
                Label("\(model.placedIDs.count) of \(model.memories.count) placed", systemImage: "building.columns")
                    .font(.headline)
                    .contentTransition(.numericText())
                Button(action: onLeave) {
                    Label("Leave", systemImage: "xmark")
                }
            }

            Label(model.status.message, systemImage: model.status.icon)
                .font(.title3)
                .animation(.default, value: model.status)

            if model.calibration == .needed {
                northCalibration
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.memories) { memory in
                        Button {
                            model.selectedID = memory.id
                        } label: {
                            MemoryChip(
                                memory: memory,
                                isSelected: memory.id == model.selectedID,
                                isPlaced: model.placedIDs.contains(memory.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Text("Look at the floor and pinch to place the selected memory.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.calibration != .needed {
                    Button {
                        model.reset()
                    } label: {
                        Label("Reset Room", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .padding(32)
        .frame(width: 900)
        .glassBackgroundEffect()
        .disabled(!model.isReady)
    }

    private var northCalibration: some View {
        HStack(spacing: 20) {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.primaryColor)
            VStack(alignment: .leading, spacing: 6) {
                Text("Vision Pro has no compass")
                    .font(.headline)
                Text("Face north (check the Compass app on your iPhone), then pinch Set North. Pinned memories will appear in the direction of where they happened.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(spacing: 10) {
                Button {
                    model.setNorth()
                } label: {
                    Label("Set North", systemImage: "location.north.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Skip") {
                    model.skipCalibration()
                }
            }
            .frame(width: 200)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
