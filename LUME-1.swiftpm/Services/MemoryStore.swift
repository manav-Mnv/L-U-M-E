import UIKit

/// Saves memories to Application Support so the journal survives app relaunches.
/// Layout: `LUME/memories.json` plus one `LUME/images/<id>.jpg` per photo.
@MainActor
final class MemoryStore {
    private let directory: URL
    private let imagesDirectory: URL
    private let indexURL: URL

    /// Identity of the last photo written for each memory, so unchanged photos are not re-encoded on every save.
    private var savedImages: [UUID: ObjectIdentifier] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("LUME", isDirectory: true)
        imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        indexURL = directory.appendingPathComponent("memories.json")
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    /// Returns `nil` when nothing has been saved yet (first launch).
    func load() -> [MemoryItem]? {
        guard let data = try? Data(contentsOf: indexURL),
              let records = try? JSONDecoder().decode([MemoryRecord].self, from: data) else {
            return nil
        }
        return records.map { record in
            var image: UIImage?
            if record.hasImage {
                image = UIImage(contentsOfFile: imageURL(for: record.id).path)
                if let image { savedImages[record.id] = ObjectIdentifier(image) }
            }
            return MemoryItem(record: record, image: image)
        }
    }

    func save(_ items: [MemoryItem]) {
        let liveIDs = Set(items.map(\.id))

        for item in items {
            let url = imageURL(for: item.id)
            if let image = item.image {
                guard savedImages[item.id] != ObjectIdentifier(image) else { continue }
                if let data = image.jpegData(compressionQuality: 0.85) {
                    try? data.write(to: url, options: .atomic)
                    savedImages[item.id] = ObjectIdentifier(image)
                }
            } else if savedImages.removeValue(forKey: item.id) != nil {
                try? FileManager.default.removeItem(at: url)
            }
        }

        for id in savedImages.keys where !liveIDs.contains(id) {
            try? FileManager.default.removeItem(at: imageURL(for: id))
            savedImages.removeValue(forKey: id)
        }

        if let data = try? JSONEncoder().encode(items.map(\.record)) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func imageURL(for id: UUID) -> URL {
        imagesDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }
}
