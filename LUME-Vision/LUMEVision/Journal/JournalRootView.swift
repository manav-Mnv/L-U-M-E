import SwiftUI

/// Intro → onboarding → journal, mirroring the iPad app's launch flow.
struct JournalRootView: View {
    private enum Stage {
        case intro, unveil, journal
    }

    @State private var stage: Stage = .intro

    var body: some View {
        ZStack {
            switch stage {
            case .intro:
                LumeIntroView()
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.8)) { stage = .unveil }
                    }
                    .transition(.opacity)
            case .unveil:
                UnveilStoryView {
                    withAnimation(.easeInOut(duration: 0.8)) { stage = .journal }
                }
                .clipped()
                .transition(.opacity)
            case .journal:
                JournalView()
                    .transition(.opacity)
            }
        }
    }
}
