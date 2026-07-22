import Foundation

struct CourseAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: KeychainTokenStore

    init(
        baseURL: URL = APIConfiguration.baseURL,
        session: URLSession = .shared,
        tokenStore: KeychainTokenStore = KeychainTokenStore()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
    }

    func fetchCourses() async throws -> [Course] {
        let token = try await bearerToken()

        do {
            return try await requestCourses(with: token)
        } catch APIClientError.unauthorized {
            try tokenStore.delete()
            let renewedToken = try await issueGuestToken()
            return try await requestCourses(with: renewedToken)
        }
    }

    private func bearerToken() async throws -> String {
        if let storedToken = try tokenStore.read() {
            return storedToken
        }
        return try await issueGuestToken()
    }

    private func issueGuestToken() async throws -> String {
        var request = URLRequest(url: endpoint("api/v1/auth/guest"))
        request.httpMethod = "POST"

        let response: GuestAuthResponse = try await send(request)
        try tokenStore.save(response.token)
        return response.token
    }

    private func requestCourses(with token: String) async throws -> [Course] {
        var request = URLRequest(url: endpoint("api/v1/courses"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let response: CourseListResponse = try await send(request)
        return response.items
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIClientError.unauthorized
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIClientError.server(code: errorResponse?.code)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIClientError.invalidPayload
        }
    }

    private func endpoint(_ path: String) -> URL {
        baseURL.appending(path: path)
    }
}

private struct GuestAuthResponse: Decodable {
    let token: String
}

private struct CourseListResponse: Decodable {
    let items: [Course]
}

private struct APIErrorResponse: Decodable {
    let code: String
}

private enum APIClientError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(code: String?)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponse, .server:
            "서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .unauthorized:
            "인증이 만료되었어요. 다시 시도해 주세요."
        case .invalidPayload:
            "코스 정보를 처리할 수 없어요. 다시 시도해 주세요."
        }
    }
}
