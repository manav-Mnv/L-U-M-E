import SwiftUI
import UIKit
import CoreLocation

struct MemoryItem: Identifiable, Hashable {
    public var id: UUID = UUID()
    var image: UIImage?
    var title: String = ""
    var body: String = ""
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date = .now

    var coordinate: CLLocationCoordinate2D? {
        get {
            if let lat = latitude, let lon = longitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Memory" : title
    }

    /// Shared "lat, lon" label used by the sidebar, the editor and the AR placards.
    var locationString: String? {
        guard let coordinate else { return nil }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - Persistence

/// The JSON record for a memory. Photos are stored as separate JPEG files by `MemoryStore`.
struct MemoryRecord: Codable {
    var id: UUID
    var title: String
    var body: String
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var hasImage: Bool
}

extension MemoryItem {
    var record: MemoryRecord {
        MemoryRecord(id: id, title: title, body: body, latitude: latitude, longitude: longitude, createdAt: createdAt, hasImage: image != nil)
    }

    init(record: MemoryRecord, image: UIImage?) {
        self.init(id: record.id, image: image, title: record.title, body: record.body, latitude: record.latitude, longitude: record.longitude, createdAt: record.createdAt)
    }
}

extension MemoryItem {
    static let preview = MemoryItem(
        image: UIImage(named: "concert"),
        title: "Keluar Kantor Macet Banget Guys",
        body: "Keluar kantor doang susah banget padahal w mau jogging sebelum maghrib, tapi ini mah nyampe kosan maghrib tapi yaudahlah"
    )
}
