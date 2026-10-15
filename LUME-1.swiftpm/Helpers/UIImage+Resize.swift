import UIKit

extension UIImage {
    /// Bakes in the EXIF orientation and caps the longest side, so camera photos
    /// stay light for saving, AR textures and ARKit image detection.
    func preparedForMemory(maxDimension: CGFloat = 2048) -> UIImage {
        let longest = max(size.width, size.height)
        let scaleFactor = min(1, maxDimension / max(longest, 1))
        let targetSize = CGSize(width: (size.width * scaleFactor).rounded(), height: (size.height * scaleFactor).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
