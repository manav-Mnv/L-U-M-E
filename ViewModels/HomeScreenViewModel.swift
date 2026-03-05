import SwiftUI

class HomeScreenViewModel: ObservableObject {
    @Published var memoryItems: [MemoryItem] = []
    
    @Published var selectedIndex: Int?
    
    // MARK: - Helpers
    
    init() {
        print("init home")
        memoryItems.append(contentsOf: HomeScreenViewModel.mockMemoryItems)
    }
    
    func memoryItem(for id: MemoryItem.ID) -> MemoryItem? {
        guard let memoryItem = memoryItems.first(where: { $0.id == id }) else {
            return nil
        }
        
        return memoryItem
    }
    
    func addMemoryItem() {
        let newMemoryItem = MemoryItem()
        withAnimation {
            memoryItems.append(newMemoryItem)
            selectedIndex = memoryItems.count - 1
        }
    }
    
}

// TODO: delete
extension HomeScreenViewModel {
    static let mockMemoryItems = [
        MemoryItem(
            image: UIImage(named: "concert"),
            title: "Swift lab",
            body: """
            The ios Swift Lab at Parul University stands as a symbol of innovation, excellence, \
            and future-ready education. As an official Apple Authorized Training Center, the lab \
            offers world-class infrastructure designed to match global Apple standards. \
            Equipped with the latest Apple Mac systems and advanced development tools like Swift \
            and Xcode, the lab provides students with hands-on experience in real-time is app \
            development. The modern setup, inspiring environment, and Apple-certified curriculum \
            empower students to transform creative ideas into powerful applications.
            """
        ),
        MemoryItem(
            image: UIImage(named: "bromo"),
            title: "CV Raman",
            body: """
            The C.V. Raman Building at Parul University stands as a remarkable blend of \
            architectural elegance and academic vitality. Its thoughtfully designed structure \
            reflects Parul's commitment to innovation while honoring the legacy of one of India's \
            greatest scientists-Sir C.V. Raman. The building's modern façade and spacious, \
            naturally lit interiors create an environment that feels both inspiring and purpose-driven. \
            Walking through its corridors, you immediately sense a culture of curiosity and \
            excellence a perfect setting for learning, research, and collaboration. The classrooms \
            and labs are intelligently laid out to facilitate interactive teaching and hands-on \
            experimentation, making complex concepts more accessible and learning more engaging. \
            More than just a building, it's a symbol of intellectual pursuit-where students are \
            encouraged to think critically, experiment boldly, and grow holistically. In every way, \
            the C.V. Raman Building embodies the spirit of scientific inquiry and stands as a proud \
            landmark of Parul University's academic legacy.
            """
        ),
    ]
}
