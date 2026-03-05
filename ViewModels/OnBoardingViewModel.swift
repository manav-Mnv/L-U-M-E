import Foundation

class OnBoardingViewModel: ObservableObject {
    @Published var state: OnBoardingState = OnBoardingState(rawValue: 0)!
    
    func advanceState(hasFinished: inout Bool) {
        if state.rawValue < OnBoardingState.allCases.count - 1 {
            state = OnBoardingState(rawValue: state.rawValue + 1)!
        } else {
            hasFinished = true
        }
    }
}

enum OnBoardingState: Int, CaseIterable {
    case backstory1 = 0
    case backstory2 = 1
    case problem = 2
    case hook = 3
    case solution = 4
    
    var body: String {
        switch self {
        case .backstory1:
            return "As a human, we all have our own beautiful memories"
        case .backstory2:
            return "As the time passed, sometimes we want to look back and\nre-experience those beautiful memories"
        case .problem:
            return "Unfortunately, to the irreversible nature of time, we can't really\nre-experience those memories"
        case .hook:
            return "But what if we can? and even walk through it?"
        case .solution:
            return "Introducing Memolane, a photo-oriented diary app that let you\nto literally walk through your memory lane using Augmented Reality"
        }
    }
}
