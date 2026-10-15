import SwiftUI

/// A glass card with the full story of a memory, shown next to its podium.
struct MemoryInfoCard: View {
    let memory: MemoryItem
    var caption: String?
    var onClose: () -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.displayTitle)
                        .font(.custom("KomorebiRegular", size: 38))
                    Text(memory.createdAt, format: .dateTime.day().month(.wide).year())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonBorderShape(.circle)
                .accessibilityLabel("Close")
            }

            if let caption {
                Label(caption, systemImage: "location.north.line.fill")
                    .font(.headline)
            }

            Text(memory.body.isEmpty ? "A memory waiting for its story." : memory.body)
                .lineLimit(8)

            if let locationString = memory.locationString {
                Label(locationString, systemImage: "mappin.and.ellipse")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove from Room", systemImage: "trash")
                }
            }
        }
        .padding(32)
        .frame(width: 520)
        .glassBackgroundEffect()
    }
}
