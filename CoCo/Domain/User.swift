import Foundation

struct User: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let accountType: AccountType
    /// Providers linked to this account. Empty for guests.
    let linkedProviders: [AuthProvider]

    init(
        id: UUID,
        displayName: String,
        accountType: AccountType,
        linkedProviders: [AuthProvider] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.accountType = accountType
        self.linkedProviders = linkedProviders
    }

    /// Older responses predate `linkedProviders`, so it decodes as empty.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        accountType = try container.decode(AccountType.self, forKey: .accountType)
        linkedProviders = try container.decodeIfPresent([AuthProvider].self, forKey: .linkedProviders) ?? []
    }
}

enum AuthProvider: String, Codable, CaseIterable, Sendable {
    case naver = "NAVER"
    case kakao = "KAKAO"

    var displayName: String {
        switch self {
        case .naver: "네이버"
        case .kakao: "카카오"
        }
    }

    /// Path segment used by the server's social login endpoints.
    var pathValue: String {
        rawValue.lowercased()
    }
}
