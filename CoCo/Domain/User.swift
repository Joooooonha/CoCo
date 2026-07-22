import Foundation

struct User: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let accountType: AccountType
}
