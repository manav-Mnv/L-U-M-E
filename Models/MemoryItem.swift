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
}

extension MemoryItem {
    static let preview = MemoryItem(
        image: UIImage(named: "concert"),
        title: "Keluar Kantor Macet Banget Guys",
        body: "Keluar kantor doang susah banget padahal w mau jogging sebelum maghrib, tapi ini mah nyampe kosan maghrib tapi yaudahlah"
    )
}
