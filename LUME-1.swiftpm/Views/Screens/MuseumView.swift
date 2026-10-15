import SwiftUI
import RealityKit
import UIKit

/// Full-screen memory museum: the AR (or 3D preview) scene plus its glass controls.
struct MuseumView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: MuseumController

    init(memories: [MemoryItem]) {
        _controller = StateObject(wrappedValue: MuseumController(memories: memories))
    }

    var body: some View {
        ZStack {
            ARViewContainer(arView: controller.arView)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                statusPill
                carousel
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(GlassCircleButtonStyle())
            .accessibilityLabel("Close museum")

            VStack(alignment: .leading, spacing: 2) {
                Text("Memory Museum")
                    .font(.custom("KomorebiRegular", size: 28))
                Text(controller.mode == .augmented ? "Augmented Reality" : "3D Preview")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 6)

            Spacer()

            Label("\(controller.placedIDs.count) of \(controller.memories.count) placed", systemImage: "building.columns")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .animation(.spring, value: controller.placedIDs.count)

            Button {
                controller.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(GlassCircleButtonStyle())
            .accessibilityLabel("Reset museum")
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Status

    private var statusPill: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.status.icon)
                .symbolEffect(.pulse, options: .repeating, isActive: !controller.status.isError)
            Text(controller.status.message)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(.subheadline, design: .rounded, weight: .medium))
        .foregroundStyle(controller.status.isError ? Color.orange : .white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: 640)
        .id(controller.status)
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: controller.status)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    // MARK: - Memory carousel

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(controller.memories) { memory in
                    MuseumMemoryChip(
                        memory: memory,
                        mode: controller.mode,
                        isSelected: controller.selectedID == memory.id,
                        isPlaced: controller.placedIDs.contains(memory.id)
                    )
                    .onTapGesture {
                        controller.select(memory.id)
                    }
                    .contextMenu {
                        if controller.placedIDs.contains(memory.id) {
                            Button(role: .destructive) {
                                controller.remove(memory.id)
                            } label: {
                                Label("Remove from Room", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .scrollClipDisabled()
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

private struct MuseumMemoryChip: View {
    let memory: MemoryItem
    let mode: MuseumController.Mode
    let isSelected: Bool
    let isPlaced: Bool
    
    private var hint: (text: String, icon: String) {
        if memory.coordinate != nil {
            return (mode == .augmented ? "Placed by GPS" : "Pinned on map", "location.fill")
        }
        return (mode == .augmented ? "Tap floor to place" : "No map pin", mode == .augmented ? "hand.tap" : "mappin.slash")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [.primaryColor, Color(hex: 0x8B5CF6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    if let image = memory.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: 150, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isPlaced {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            Text(memory.displayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Label(hint.text, systemImage: hint.icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 150)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? Color.primaryColor.opacity(0.6) : Color.white.opacity(0.08))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(isSelected ? 0.85 : 0.15), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isPlaced)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
