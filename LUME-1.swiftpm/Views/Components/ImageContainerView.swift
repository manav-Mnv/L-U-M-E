import SwiftUI

/// The framed print shown above each podium. Rendered to a texture whose 3:4
/// canvas matches the 0.72 m × 0.96 m photo plane.
struct ImageContainerView: View {
    let uiImage: UIImage?

    var body: some View {
        ZStack {
            Color(hex: 0xFBF8F1)

            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 40) {
                            Image(systemName: "photo")
                                .font(.system(size: 240, weight: .ultraLight))
                            Text("No Photo")
                                .font(.system(size: 96, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .clipped()
                .padding(90)
        }
        .frame(width: 1152, height: 1536)
        .overlay(Rectangle().strokeBorder(Color(hex: 0x1E1B2E), lineWidth: 28))
    }
}
