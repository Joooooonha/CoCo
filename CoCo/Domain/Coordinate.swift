import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

/// A latitude/longitude bounding box describing the visible map area,
/// kept SDK-free so stores never depend on MapKit types.
struct MapViewport: Equatable, Sendable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    func intersects(
        minLatitude otherMinLatitude: Double,
        maxLatitude otherMaxLatitude: Double,
        minLongitude otherMinLongitude: Double,
        maxLongitude otherMaxLongitude: Double
    ) -> Bool {
        otherMinLatitude <= maxLatitude && otherMaxLatitude >= minLatitude
            && otherMinLongitude <= maxLongitude && otherMaxLongitude >= minLongitude
    }
}

struct RoutePoint: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let sequence: Int
    let latitude: Double
    let longitude: Double

    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}
