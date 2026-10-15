import SwiftUI

/// Sidebar row. Selection is handled by the parent `List(selection:)`, so the card only needs its own item.
struct MemoryCard: View {
    let memoryItem: MemoryItem

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(memoryItem.displayTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(memoryItem.title.isEmpty ? .secondary : .primary)
                    .lineLimit(1)

                Text(memoryItem.body.isEmpty ? "No story yet — tap to write one." : memoryItem.body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Text(memoryItem.createdAt, format: .dateTime.day().month(.abbreviated).year())
                    if memoryItem.coordinate != nil {
                        Label("Pinned", systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(colors: [Color.primaryColor.opacity(0.75), Color(hex: 0x8B5CF6).opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay {
                if let image = memoryItem.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
