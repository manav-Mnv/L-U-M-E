import SwiftUI

struct UnveilStoryView: View {
    // Action closure to transition to the main app
    var onReveal: () -> Void

    // Animation states
    @State private var isAnimatingBg = false
    @State private var isAnimatingCard = false
    @State private var tilt: CGSize = .zero

    private let cyan = Color(red: 0.1, green: 0.9, blue: 0.8)
    private let blue = Color(red: 0.2, green: 0.7, blue: 0.9)

    var body: some View {
        ZStack {
            // MARK: - Cosmic Background
            Image("bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .scaleEffect(isAnimatingBg ? 1.0 : 1.1)
                .animation(.easeOut(duration: 8.0).repeatForever(autoreverses: true), value: isAnimatingBg)

            // MARK: - Glassmorphic Card
            VStack(alignment: .leading, spacing: 22) {

                // LUME Label
                Text("LUME")
                    .font(.custom("KomorebiRegular", size: 18))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.8))

                // Main Title
                Text("Unveil\nYour Story")
                    .font(.custom("KomorebiRegular", size: 60))
                    .foregroundColor(.white)
                    .lineSpacing(-2)

                // Subtitle
                Text("Transform written memories into living moments through augmented reality.")
                    .font(.custom("KomorebiRegular", size: 20))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(5)

                VStack(alignment: .leading, spacing: 14) {
                    featureRow(icon: "camera.fill", text: "Capture a moment and its story")
                    featureRow(icon: "mappin.and.ellipse", text: "Pin exactly where it happened")
                    featureRow(icon: "building.columns.fill", text: "Walk through it as an AR museum")
                }
                .padding(.top, 6)

                Spacer(minLength: 8)

                // Action Button
                Button(action: onReveal) {
                    HStack(spacing: 10) {
                        Text("Reveal Memory")
                        Image(systemName: "arrow.right")
                    }
                    .font(.custom("KomorebiRegular", size: 22).weight(.bold))
                    .foregroundColor(Color(hex: 0x0B1026))
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [cyan, blue], startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: cyan.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(40)
            .frame(width: 480, height: 620)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    // Very subtle white border to enhance the glass edge
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 14)
            // Drag the card to tilt it like a sheet of glass.
            .rotation3DEffect(.degrees(Double(tilt.width) / 18), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(Double(-tilt.height) / 18), axis: (x: 1, y: 0, z: 0))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        tilt = CGSize(
                            width: min(max(value.translation.width, -180), 180),
                            height: min(max(value.translation.height, -180), 180)
                        )
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                            tilt = .zero
                        }
                    }
            )
            // Entrance animation variables
            .opacity(isAnimatingCard ? 1 : 0)
            .offset(y: isAnimatingCard ? 0 : 30)
        }
        .onAppear {
            isAnimatingBg = true

            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                isAnimatingCard = true
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(cyan)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1), in: Circle())
            Text(text)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

#Preview {
    UnveilStoryView(onReveal: {})
}
