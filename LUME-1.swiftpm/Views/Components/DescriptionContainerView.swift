import SwiftUI

/// The museum placard on the front of each podium. Rendered to a texture, so the
/// 2000×1200 canvas matches the 0.5 m × 0.3 m placard plane (no stretching).
struct DescriptionContainerView: View {
    let title: String
    let description: String
    var locationString: String? = nil
    /// Extra line for GPS-placed memories, e.g. "1.2 km away · NE".
    var caption: String? = nil

    private let ink = Color(hex: 0x0F172A)
    private let accent = Color(hex: 0x6366F1)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("LUME · MEMORY")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .tracking(10)
                    .foregroundStyle(accent)
                Spacer()
                if let caption {
                    HStack(spacing: 14) {
                        Image(systemName: "location.north.line.fill")
                        Text(caption)
                    }
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 18)
                    .background(accent, in: Capsule())
                }
            }

            Text(title)
                .font(.custom("KomorebiRegular", size: 150))
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(.top, 40)

            Rectangle()
                .fill(accent)
                .frame(width: 160, height: 8)
                .padding(.vertical, 44)

            Text(description.isEmpty ? "A memory waiting for its story." : description)
                .font(.system(size: 56, design: .serif))
                .foregroundStyle(ink.opacity(0.8))
                .lineSpacing(14)
                .lineLimit(6)

            Spacer(minLength: 0)

            if let locationString {
                HStack(spacing: 18) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(locationString)
                }
                .font(.system(size: 50, weight: .semibold, design: .rounded))
                .foregroundStyle(ink.opacity(0.55))
            }
        }
        .padding(110)
        .frame(width: 2000, height: 1200, alignment: .topLeading)
        .background(Color(hex: 0xFBF8F1))
        .overlay(Rectangle().strokeBorder(Color(hex: 0xE7E1D3), lineWidth: 24))
    }
}

#Preview {
    DescriptionContainerView(title: "Swift Lab", description: MemoryItem.preview.body, locationString: "22.2887, 73.3637", caption: "1.2 km away · NE")
        .scaleEffect(0.3)
}
