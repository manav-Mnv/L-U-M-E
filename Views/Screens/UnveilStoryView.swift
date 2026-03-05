import SwiftUI

struct UnveilStoryView: View {
    // Action closure to transition to the main app
    var onReveal: () -> Void
    
    // Animation states
    @State private var isAnimatingBg = false
    @State private var isAnimatingCard = false
    
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
            VStack(alignment: .leading, spacing: 20) {
                
                // LUME Label
                Text("LUME")
                    .font(.custom("KomorebiRegular", size: 14))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.8))
                
                // Main Title
                Text("Unveil\nYour Story")
                    .font(.custom("KomorebiRegular", size: 42))
                    .foregroundColor(.white)
                    .lineSpacing(-2)
                
                // Subtitle
                Text("Transform written memories into living moments through augmented reality.")
                    .font(.custom("KomorebiRegular", size: 16))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 4)
                    .lineSpacing(4)
                
                Spacer()
                
                // Action Button
                HStack {
                    Spacer()
                    Button(action: onReveal) {
                        Text("Reveal Memory")
                            .font(.custom("KomorebiRegular", size: 18))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 32)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.1, green: 0.9, blue: 0.8), // Cyan
                                                Color(red: 0.2, green: 0.7, blue: 0.9)  // Blue
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color(red: 0.1, green: 0.9, blue: 0.8).opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            .padding(32)
            .frame(width: 340, height: 420) // Adjust height explicitly for the card proportion
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    // Very subtle white border to enhance the glass edge
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            // Entrance animation variables
            .opacity(isAnimatingCard ? 1 : 0)
            .offset(y: isAnimatingCard ? 0 : 20)
        }
        .onAppear {
            isAnimatingBg = true
            
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                isAnimatingCard = true
            }
        }
    }
}

#Preview {
    UnveilStoryView(onReveal: {})
}
