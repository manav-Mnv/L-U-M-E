import CoreLocation
import simd

/// GPS → room placement. Vision Pro has no compass, so "north" is a direction the
/// user calibrates once in the immersive museum.
enum GeoPlacement {
    /// Initial great-circle bearing from `origin` to `target`, in radians clockwise from true north.
    static func bearing(from origin: CLLocationCoordinate2D, to target: CLLocationCoordinate2D) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = target.latitude * .pi / 180
        let dLon = (target.longitude - origin.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x)
    }

    /// Real-world distance → a walkable distance in the room: 1:1 up close, then
    /// compressed logarithmically so even a memory in another city stays within ~8 m.
    static func walkableRadius(forDistance distance: CLLocationDistance) -> Float {
        if distance <= 3 { return Float(max(distance, 1.6)) }
        return Float(min(3 + log10(distance / 3) * 1.4, 8))
    }

    static func distanceCaption(distance: CLLocationDistance, bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let degrees = (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        let compass = directions[Int((degrees + 22.5) / 45) % 8]
        let formatted = distance < 1000
            ? "\(Int(distance.rounded())) m"
            : String(format: distance < 100_000 ? "%.1f km" : "%.0f km", distance / 1000)
        return "\(formatted) away · \(compass)"
    }

    /// Turns the calibrated north direction clockwise (seen from above) by `bearing`.
    static func direction(bearing: Double, north: SIMD3<Float>) -> SIMD3<Float> {
        simd_normalize(simd_quatf(angle: -Float(bearing), axis: [0, 1, 0]).act(north))
    }
}
