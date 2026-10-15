import SwiftUI
import Observation

/// Museum state shared by the journal window, the tabletop volume and the immersive space.
@MainActor
@Observable
final class MuseumSession {
    enum ImmersiveState {
        case closed, inTransition, open
    }

    var immersiveState: ImmersiveState = .closed

    /// The memory the journal asked the museums to bring to the front.
    var focusedMemoryID: UUID?
}
