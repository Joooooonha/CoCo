import Foundation
import Observation

/// Whether the app currently holds a usable token.
///
/// Every account now comes from a social provider. That is what lets an account
/// outlive the device that created it: the identity lives with Naver or Kakao,
/// not in this app's keychain. So when there is no token, or the server rejects
/// the one we have, the answer is to sign in again — never to quietly mint a
/// new anonymous account, which would leave the previous one unreachable.
@MainActor
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var isSignedIn: Bool

    @ObservationIgnored private let tokenStore: KeychainTokenStore

    init(tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.tokenStore = tokenStore
        self.isSignedIn = (try? tokenStore.read()) != nil
    }

    /// Called after a social login stores its token.
    func didSignIn() {
        isSignedIn = true
    }

    /// Called when the server refuses the token, and after logout or account
    /// deletion. The stored token is already useless, so it goes too.
    func didSignOut() {
        try? tokenStore.delete()
        CurrentUserID.value = nil
        CurrentUserName.value = nil
        isSignedIn = false
    }
}
