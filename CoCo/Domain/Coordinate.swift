import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
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
