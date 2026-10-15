import SwiftUI

struct LumeIntroView: View {
    @State private var isAnimating = false
    
    // MARK: - Design Constants
    // Matching the gold/amber tone from your new image
    let goldColor = Color(red: 1.0, green: 0.84, blue: 0.45) 
    let appleCurve = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.6)
    let initialDelay = 0.6
    let stagger = 0.15

    var body: some View {
        ZStack {
            // MARK: - Background
            Image("bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .scaleEffect(isAnimating ? 1.0 : 1.15) // Slow, deep zoom
                .animation(.easeOut(duration: 4.0), value: isAnimating)

            VStack(spacing: 50) {
                // MARK: - Tagline
                Text("LIGHT UNVEILS MEMORY ENVIRONMENT")
                    .font(.custom("KomorebiRegular", size: 14))
                    .kerning(3)
                    .foregroundColor(goldColor.opacity(0.7))
                    .opacity(isAnimating ? 1 : 0)
                    .animation(appleCurve.delay(0.2), value: isAnimating)

                // MARK: - High-Fashion Typography
                HStack(spacing: 35) {
                    // L: Drops from top
                    LetterView(char: "L", color: goldColor, isAnimating: isAnimating)
                        .offset(y: isAnimating ? 0 : -40)
                        .animation(appleCurve.delay(initialDelay), value: isAnimating)

                    // U: Slides from right
                    LetterView(char: "U", color: goldColor, isAnimating: isAnimating)
                        .offset(x: isAnimating ? 0 : 40)
                        .animation(appleCurve.delay(initialDelay + stagger), value: isAnimating)

                    // M: Slides from left
                    LetterView(char: "M", color: goldColor, isAnimating: isAnimating)
                        .offset(x: isAnimating ? 0 : -40)
                        .animation(appleCurve.delay(initialDelay + (stagger * 2)), value: isAnimating)

                    // E: Rises from bottom
                    LetterView(char: "E", color: goldColor, isAnimating: isAnimating)
                        .offset(y: isAnimating ? 0 : 40)
                        .animation(appleCurve.delay(initialDelay + (stagger * 3)), value: isAnimating)
                }
                // Glow effect to match the vibrant nebula
                .shadow(color: goldColor.opacity(0.5), radius: isAnimating ? 12 : 0)

                // MARK: - Minimalist Icon
                Image(systemName: "cube.transparent")
                    .font(.system(size: 45, weight: .ultraLight)) // Matches the high-fashion thin font lines
                    .foregroundColor(goldColor.opacity(0.8)) // Luminous gold tone
                    
                    // 1. Entrance: Emerges from deep space
                    .opacity(isAnimating ? 1 : 0)
                    .scaleEffect(isAnimating ? 1.0 : 0.7)
                    
                    // 2. Motion: Architectural 3D fold-forward
                    .rotation3DEffect(
                        .degrees(isAnimating ? 0 : -110),
                        axis: (x: 1, y: 0.2, z: 0.1)
                    )
                    
                    // 3. Bloom: Subtle amber glow
                    .shadow(color: goldColor.opacity(isAnimating ? 0.6 : 0), radius: 10)
                    
                    // 4. Timing: The final anchor to settle
                    .animation(
                        Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.8).delay(1.4), 
                        value: isAnimating
                    )
            }
            
            // MARK: - Tap to Continue Prompt
            VStack {
                Spacer()
                Text("TAP TO EXPLORE")
                    .font(.custom("KomorebiRegular", size: 20))
                    .kerning(2)
                    .foregroundColor(goldColor.opacity(0.8))
                    .opacity(isAnimating ? 1 : 0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(initialDelay + 2.0),
                        value: isAnimating
                    )
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Updated Letter View
struct LetterView: View {
    let char: String
    let color: Color
    let isAnimating: Bool
    
    var body: some View {
        Text(char)
            .font(.custom("KomorebiRegular", size: 160))
            .kerning(4) // Extra spacing for that architectural look
            .foregroundColor(color)
            .opacity(isAnimating ? 1 : 0)
            .blur(radius: isAnimating ? 0 : 10)
            .scaleEffect(isAnimating ? 1 : 0.9)
    }
}

#Preview {
    LumeIntroView()
}
