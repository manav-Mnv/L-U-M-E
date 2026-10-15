import SwiftUI

@MainActor
final class HomeScreenViewModel: ObservableObject {
    @Published var memoryItems: [MemoryItem] = [] {
        didSet { scheduleSave() }
    }

    /// Selection is tracked by ID (not array index) so deleting or reordering can never point at a stale slot.
    @Published var selectedID: MemoryItem.ID?

    @Published var searchText = ""

    private let store = MemoryStore()
    private var saveTask: Task<Void, Never>?

    init() {
        memoryItems = store.load() ?? HomeScreenViewModel.mockMemoryItems
        selectedID = memoryItems.first?.id
    }

    // MARK: - Helpers

    var filteredItems: [MemoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return memoryItems }
        return memoryItems.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    func memoryItem(for id: MemoryItem.ID) -> MemoryItem? {
        memoryItems.first(where: { $0.id == id })
    }

    /// A binding that looks the memory up by ID on every access, so it stays valid
    /// even if the array is mutated while the editor is on screen.
    func binding(for id: MemoryItem.ID) -> Binding<MemoryItem>? {
        guard let current = memoryItem(for: id) else { return nil }
        return Binding(
            get: { [weak self] in self?.memoryItem(for: id) ?? current },
            set: { [weak self] newValue in
                guard let self, let index = self.memoryItems.firstIndex(where: { $0.id == id }) else { return }
                self.memoryItems[index] = newValue
            }
        )
    }

    func addMemoryItem() {
        let newMemoryItem = MemoryItem()
        searchText = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            memoryItems.insert(newMemoryItem, at: 0)
            selectedID = newMemoryItem.id
        }
    }

    func deleteMemoryItem(id: MemoryItem.ID) {
        guard let index = memoryItems.firstIndex(where: { $0.id == id }) else { return }
        guard selectedID == id else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                _ = memoryItems.remove(at: index)
            }
            return
        }
        // Move the selection to a neighbour first, then remove the row on the next tick;
        // removing the selected row directly makes the List drop its selection highlight.
        let remaining = memoryItems.filter { $0.id != id }
        selectedID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        Task { @MainActor [weak self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                self?.memoryItems.removeAll { $0.id == id }
            }
        }
    }

    func duplicateMemoryItem(id: MemoryItem.ID) {
        guard let index = memoryItems.firstIndex(where: { $0.id == id }) else { return }
        var copy = memoryItems[index]
        copy.id = UUID()
        copy.createdAt = .now
        copy.title = copy.title.isEmpty ? "" : "\(copy.title) (Copy)"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            memoryItems.insert(copy, at: index + 1)
            selectedID = copy.id
        }
    }

    // MARK: - Persistence

    /// Debounced so typing in the editor doesn't hit the disk on every keystroke.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            self.store.save(self.memoryItems)
        }
    }
}

// Seed content shown on first launch.
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
