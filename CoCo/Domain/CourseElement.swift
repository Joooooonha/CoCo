import Foundation

struct CourseElement: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let courseId: UUID
    let category: ElementCategory
    let latitude: Double
    let longitude: Double
    let distanceFromStartMeters: Int
    let title: String
    let description: String

    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}
