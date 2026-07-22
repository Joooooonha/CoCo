import Foundation

struct ReactionCounts: Codable, Hashable, Sendable {
    let like: Int
    let hard: Int
    let scenic: Int

    func count(for reaction: ReactionType) -> Int {
        switch reaction {
        case .like: like
        case .hard: hard
        case .scenic: scenic
        }
    }
}

struct Course: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    let ownerName: String
    let name: String
    let summary: String
    let difficulty: CourseDifficulty
    let locationLabel: String
    let distanceMeters: Int
    let estimatedDurationSeconds: Int
    let routeSource: RouteSource
    let routePoints: [RoutePoint]
    let elements: [CourseElement]
    let scrapCount: Int
    let reactionCounts: ReactionCounts
    let isScrapped: Bool
    let myReactions: Set<ReactionType>

    var distanceKilometers: Double {
        Double(distanceMeters) / 1_000
    }

    var estimatedMinutes: Int {
        Int(ceil(Double(estimatedDurationSeconds) / 60))
    }
}
