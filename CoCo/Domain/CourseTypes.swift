import Foundation

enum AccountType: String, Codable, Sendable {
    case guest = "GUEST"
    case member = "MEMBER"
}

enum CourseDifficulty: String, Codable, CaseIterable, Sendable {
    case easy = "EASY"
    case moderate = "MODERATE"
    case hard = "HARD"

    var displayName: String {
        switch self {
        case .easy: "쉬움"
        case .moderate: "보통"
        case .hard: "어려움"
        }
    }
}

enum ElementCategory: String, Codable, CaseIterable, Sendable {
    case view = "VIEW"
    case caution = "CAUTION"
    case facility = "FACILITY"

    var displayName: String {
        switch self {
        case .view: "경관"
        case .caution: "주의"
        case .facility: "편의"
        }
    }
}

enum ReactionType: String, Codable, CaseIterable, Hashable, Sendable {
    case like = "LIKE"
    case hard = "HARD"
    case scenic = "SCENIC"

    var displayName: String {
        switch self {
        case .like: "좋아요"
        case .hard: "힘들어요"
        case .scenic: "경관이 좋아요"
        }
    }
}

enum RouteSource: String, Codable, Sendable {
    case plannedMapKit = "PLANNED_MAPKIT"
    case recordedGPS = "RECORDED_GPS"
    case importedGPX = "IMPORTED_GPX"
    case drawnFreehand = "DRAWN_FREEHAND"
    case plannedKakao = "PLANNED_KAKAO"

    /// Freehand routes skip road snapping, so the app tells other runners where
    /// the line came from instead of hiding it.
    var badgeLabel: String? {
        switch self {
        case .drawnFreehand: "직접 그린 경로"
        case .importedGPX: "가져온 경로"
        case .plannedMapKit, .recordedGPS, .plannedKakao: nil
        }
    }
}
