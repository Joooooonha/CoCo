import Foundation

struct ReactionCounts: Codable, Hashable, Sendable {
    var like: Int
    var hard: Int
    var scenic: Int

    func count(for reaction: ReactionType) -> Int {
        switch reaction {
        case .like: like
        case .hard: hard
        case .scenic: scenic
        }
    }

    mutating func adjust(_ reaction: ReactionType, by delta: Int) {
        switch reaction {
        case .like: like = max(0, like + delta)
        case .hard: hard = max(0, hard + delta)
        case .scenic: scenic = max(0, scenic + delta)
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
    var elements: [CourseElement]
    var scrapCount: Int
    var reactionCounts: ReactionCounts
    var isScrapped: Bool
    var myReactions: Set<ReactionType>

    var distanceKilometers: Double {
        Double(distanceMeters) / 1_000
    }

    var estimatedMinutes: Int {
        Int(ceil(Double(estimatedDurationSeconds) / 60))
    }

    mutating func setScrapped(_ newValue: Bool) {
        guard isScrapped != newValue else { return }
        isScrapped = newValue
        scrapCount = max(0, scrapCount + (newValue ? 1 : -1))
    }

    mutating func upsertElement(_ element: CourseElement) {
        if let index = elements.firstIndex(where: { $0.id == element.id }) {
            elements[index] = element
        } else {
            elements.append(element)
        }
        elements.sort {
            ($0.distanceFromStartMeters, $0.id.uuidString) < ($1.distanceFromStartMeters, $1.id.uuidString)
        }
    }

    mutating func removeElement(id elementID: UUID) {
        elements.removeAll { $0.id == elementID }
    }

    mutating func setReaction(_ type: ReactionType, isOn: Bool) {
        guard myReactions.contains(type) != isOn else { return }
        if isOn {
            myReactions.insert(type)
        } else {
            myReactions.remove(type)
        }
        reactionCounts.adjust(type, by: isOn ? 1 : -1)
    }
}
