import Foundation
import Observation

@MainActor
@Observable
final class AccountStore {
    private(set) var user: User?
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    /// Set after logout or deletion so callers can refresh course-facing state.
    private(set) var sessionDidReset = false

    @ObservationIgnored private let apiClient: CourseAPIClient
    @ObservationIgnored private let loginSession: SocialLoginSession

    init(
        user: User? = nil,
        apiClient: CourseAPIClient = CourseAPIClient(),
        loginSession: SocialLoginSession? = nil
    ) {
        self.user = user
        self.apiClient = apiClient
        self.loginSession = loginSession ?? SocialLoginSession()
    }

    var isSignedIn: Bool {
        user?.accountType == .member
    }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            user = try await apiClient.fetchCurrentUser()
        } catch {
            // A missing profile is not worth interrupting the screen for; the
            // guest session still works and the next attempt can recover.
            user = nil
        }
    }

    func signIn(with provider: AuthProvider) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let state = UUID().uuidString
            let authorization = try await apiClient.fetchAuthorizeURL(provider: provider, state: state)
            guard let authorizeURL = URL(string: authorization.authorizeUrl) else {
                errorMessage = "로그인 주소를 만들지 못했어요. 잠시 후 다시 시도해 주세요."
                return
            }

            let code = try await loginSession.authorize(
                provider: provider,
                authorizeURL: authorizeURL,
                expectedState: state
            )
            user = try await apiClient.completeSocialLogin(
                provider: provider,
                code: code,
                redirectURI: authorization.redirectUri
            )
            sessionDidReset = true
        } catch SocialLoginError.cancelled {
            // Dismissing the provider screen is a normal outcome, not an error.
        } catch let loginError as SocialLoginError {
            errorMessage = loginError.errorDescription
        } catch {
            errorMessage = "로그인하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func signOut() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await apiClient.logout()
            user = nil
            sessionDidReset = true
        } catch {
            errorMessage = "로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func deleteAccount() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await apiClient.deleteAccount()
            user = nil
            sessionDidReset = true
        } catch {
            errorMessage = "계정을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func acknowledgeSessionReset() {
        sessionDidReset = false
    }

    func clearError() {
        errorMessage = nil
    }
}
