import AuthenticationServices
import Foundation

enum SocialLoginError: LocalizedError, Equatable {
    case cancelled
    case stateMismatch
    case providerDenied
    case malformedCallback

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "로그인을 취소했어요."
        case .stateMismatch:
            "로그인 응답을 확인하지 못했어요. 다시 시도해 주세요."
        case .providerDenied:
            "제공자가 로그인을 완료하지 못했어요. 다시 시도해 주세요."
        case .malformedCallback:
            "로그인 응답이 올바르지 않아요. 다시 시도해 주세요."
        }
    }
}

/// Runs the OAuth 2.0 authorization step in the system browser and returns the
/// authorization code. The client secret never leaves the server, so this only
/// handles the redirect and the CSRF `state` check.
@MainActor
final class SocialLoginSession: NSObject {
    private let callbackScheme: String
    private var session: ASWebAuthenticationSession?

    init(callbackScheme: String = "coco") {
        self.callbackScheme = callbackScheme
    }

    func authorize(
        provider: AuthProvider,
        authorizeURL: URL,
        expectedState: String
    ) async throws -> String {
        let callbackURL = try await presentSession(url: authorizeURL)
        return try authorizationCode(from: callbackURL, expectedState: expectedState)
    }

    private func presentSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    let isCancellation = (error as? ASWebAuthenticationSessionError)?.code
                        == .canceledLogin
                    continuation.resume(
                        throwing: isCancellation ? SocialLoginError.cancelled : SocialLoginError.providerDenied
                    )
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: SocialLoginError.malformedCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            // Keeps the provider's existing web session out of the app's cookie
            // store so the login screen always asks explicitly.
            session.prefersEphemeralWebBrowserSession = true
            self.session = session

            if !session.start() {
                continuation.resume(throwing: SocialLoginError.providerDenied)
            }
        }
    }

    private func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw SocialLoginError.malformedCallback
        }
        let items = components.queryItems ?? []

        if items.first(where: { $0.name == "error" })?.value != nil {
            throw SocialLoginError.providerDenied
        }
        guard let state = items.first(where: { $0.name == "state" })?.value, state == expectedState else {
            throw SocialLoginError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw SocialLoginError.malformedCallback
        }
        return code
    }
}

extension SocialLoginSession: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
