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
        try await fetchCourseList(path: "api/v1/courses")
    }

    func fetchMyScraps() async throws -> [Course] {
        try await fetchCourseList(path: "api/v1/me/scraps")
    }

    func fetchMyCourses() async throws -> [Course] {
        try await fetchCourseList(path: "api/v1/me/courses")
    }

    func createCourse(_ payload: CourseCreatePayload) async throws -> Course {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/courses"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            return try await send(request)
        }
    }

    func updateScrap(courseID: UUID, isScrapped: Bool) async throws {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/courses/\(courseID.uuidString)/scrap"))
            request.httpMethod = isScrapped ? "PUT" : "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            try await sendExpectingSuccess(request)
        }
    }

    func updateReaction(courseID: UUID, type: ReactionType, isOn: Bool) async throws {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/courses/\(courseID.uuidString)/reactions/\(type.rawValue)"))
            request.httpMethod = isOn ? "PUT" : "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            try await sendExpectingSuccess(request)
        }
    }

    private func fetchCourseList(path: String) async throws -> [Course] {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint(path))
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let response: CourseListResponse = try await send(request)
            return response.items
        }
    }

    private func withAuthorization<Value>(
        _ operation: (String) async throws -> Value
    ) async throws -> Value {
        let token = try await bearerToken()

        do {
            return try await operation(token)
        } catch APIClientError.unauthorized {
            try tokenStore.delete()
            let renewedToken = try await issueGuestToken()
            return try await operation(renewedToken)
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

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data = try await validatedData(for: request)

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIClientError.invalidPayload
        }
    }

    private func sendExpectingSuccess(_ request: URLRequest) async throws {
        _ = try await validatedData(for: request)
    }

    private func validatedData(for request: URLRequest) async throws -> Data {
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

        return data
    }

    private func endpoint(_ path: String) -> URL {
        baseURL.appending(path: path)
    }
}

struct CourseCreatePayload: Encodable, Sendable {
    struct RoutePointPayload: Encodable, Sendable {
        let sequence: Int
        let latitude: Double
        let longitude: Double
    }

    struct ElementPayload: Encodable, Sendable {
        let category: ElementCategory
        let latitude: Double
        let longitude: Double
        let distanceFromStartMeters: Int
        let title: String
        let description: String
    }

    let name: String
    let summary: String
    let difficulty: CourseDifficulty
    let distanceMeters: Int
    let estimatedDurationSeconds: Int
    let routeSource: RouteSource
    let routePoints: [RoutePointPayload]
    let elements: [ElementPayload]
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
