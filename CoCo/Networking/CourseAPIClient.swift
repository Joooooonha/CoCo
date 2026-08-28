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
            let course: Course = try await send(request)
            CurrentUserID.value = course.ownerId
            return course
        }
    }

    func deleteCourse(courseID: UUID) async throws {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/courses/\(courseID.uuidString)"))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            try await sendExpectingSuccess(request)
        }
    }

    func addElement(courseID: UUID, _ payload: CourseCreatePayload.ElementPayload) async throws -> CourseElement {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/courses/\(courseID.uuidString)/elements"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            return try await send(request)
        }
    }

    func updateElement(
        courseID: UUID,
        elementID: UUID,
        _ payload: CourseCreatePayload.ElementPayload
    ) async throws -> CourseElement {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/courses/\(courseID.uuidString)/elements/\(elementID.uuidString)"))
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            return try await send(request)
        }
    }

    func deleteElement(courseID: UUID, elementID: UUID) async throws {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/courses/\(courseID.uuidString)/elements/\(elementID.uuidString)"))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            try await sendExpectingSuccess(request)
        }
    }

    // MARK: - Element photos

    /// Uploads a photo in the three steps the server expects: ask for a
    /// presigned URL, send the bytes straight to storage, then confirm so the
    /// server records the object it can verify for itself.
    ///
    /// `photo` must already be processed by `ElementPhotoProcessor`; the raw
    /// bytes from the picker still carry the capture location.
    func uploadElementPhoto(
        courseID: UUID,
        elementID: UUID,
        photo: ElementPhotoProcessor.Output
    ) async throws -> CourseElement {
        let ticket = try await requestUploadTicket(
            courseID: courseID,
            elementID: elementID,
            contentType: photo.contentType,
            contentLength: photo.data.count
        )
        try await putToStorage(photo, using: ticket)
        return try await confirmUpload(
            courseID: courseID,
            elementID: elementID,
            contentType: photo.contentType
        )
    }

    func deleteElementPhoto(courseID: UUID, elementID: UUID) async throws {
        try await withAuthorization { token in
            var request = URLRequest(url: photoEndpoint(courseID: courseID, elementID: elementID))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            try await sendExpectingSuccess(request)
        }
    }

    /// Downloads photo bytes from a presigned URL. No CoCo token is involved:
    /// the signature in the URL is the entire authorization.
    func fetchPhotoData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.photoUnavailable
        }
        return data
    }

    private func requestUploadTicket(
        courseID: UUID,
        elementID: UUID,
        contentType: String,
        contentLength: Int
    ) async throws -> PhotoUploadTicket {
        try await withAuthorization { token in
            var request = URLRequest(
                url: photoEndpoint(courseID: courseID, elementID: elementID).appending(path: "upload-url")
            )
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(
                PhotoUploadRequest(contentType: contentType, contentLength: contentLength)
            )
            return try await send(request)
        }
    }

    /// Goes straight to object storage. The CoCo token must not be attached:
    /// storage would reject a request carrying two kinds of authorization, and
    /// it has no business seeing our token anyway.
    private func putToStorage(_ photo: ElementPhotoProcessor.Output, using ticket: PhotoUploadTicket) async throws {
        guard let uploadURL = URL(string: ticket.uploadURL) else {
            throw APIClientError.invalidResponse
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        // The content type is part of the signature, so a mismatch here fails
        // with a storage-side 403 rather than anything CoCo can explain.
        request.setValue(ticket.contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.upload(for: request, from: photo.data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.photoUploadRejected
        }
    }

    private func confirmUpload(
        courseID: UUID,
        elementID: UUID,
        contentType: String
    ) async throws -> CourseElement {
        try await withAuthorization { token in
            var request = URLRequest(url: photoEndpoint(courseID: courseID, elementID: elementID))
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(PhotoConfirmRequest(contentType: contentType))
            return try await send(request)
        }
    }

    private func photoEndpoint(courseID: UUID, elementID: UUID) -> URL {
        endpoint("api/v1/courses/\(courseID.uuidString)/elements/\(elementID.uuidString)/photo")
    }

    func updateDisplayName(_ displayName: String) async throws -> User {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/me"))
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["displayName": displayName])
            let user: User = try await send(request)
            CurrentUserID.value = user.id
            CurrentUserName.value = user.displayName
            return user
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
            if path == "api/v1/me/courses", let ownedCourse = response.items.first {
                CurrentUserID.value = ownedCourse.ownerId
            }
            return response.items
        }
    }

    // MARK: - Account

    func fetchCurrentUser() async throws -> User {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/me"))
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let user: User = try await send(request)
            CurrentUserID.value = user.id
            CurrentUserName.value = user.displayName
            return user
        }
    }

    /// Asks the server for the provider authorization URL so no provider client
    /// identifier has to ship inside the app.
    func fetchAuthorizeURL(provider: AuthProvider, state: String) async throws -> AuthorizeURLResponse {
        var components = URLComponents(
            url: endpoint("api/v1/auth/social/\(provider.pathValue)/authorize-url"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "state", value: state)]
        guard let url = components?.url else {
            throw APIClientError.invalidResponse
        }
        return try await send(URLRequest(url: url))
    }

    /// Exchanges the authorization code for a CoCo token. The current guest token
    /// is sent along so the server can carry the guest's data into the account.
    func completeSocialLogin(
        provider: AuthProvider,
        code: String,
        redirectURI: String
    ) async throws -> User {
        var request = URLRequest(url: endpoint("api/v1/auth/social/\(provider.pathValue)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let guestToken = try? tokenStore.read() {
            request.setValue("Bearer \(guestToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            SocialLoginPayload(code: code, redirectUri: redirectURI)
        )

        let response: AuthResponse = try await send(request)
        try tokenStore.save(response.token)
        CurrentUserID.value = response.user.id
        CurrentUserName.value = response.user.displayName
        await SessionStore.shared.didSignIn()
        return response.user
    }

    /// Revokes the current token and drops local state so the next call starts
    /// a fresh guest session.
    func logout() async throws {
        if let token = try? tokenStore.read() {
            var request = URLRequest(url: endpoint("api/v1/auth/logout"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // A rejected token is already unusable, so treat failure as success.
            try? await sendExpectingSuccess(request)
        }
        await clearLocalSession()
    }

    func deleteAccount() async throws {
        try await withAuthorization { token in
            var request = URLRequest(url: endpoint("api/v1/me"))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            try await sendExpectingSuccess(request)
        }
        await clearLocalSession()
    }

    private func clearLocalSession() async {
        await SessionStore.shared.didSignOut()
    }

    /// A rejected token sends the user back to sign-in rather than silently
    /// creating a replacement account. The old account still holds their
    /// courses, and only their social identity can reach it again.
    private func withAuthorization<Value>(
        _ operation: (String) async throws -> Value
    ) async throws -> Value {
        guard let token = try tokenStore.read() else {
            await SessionStore.shared.didSignOut()
            throw APIClientError.unauthorized
        }

        do {
            return try await operation(token)
        } catch APIClientError.unauthorized {
            await SessionStore.shared.didSignOut()
            throw APIClientError.unauthorized
        }
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

private struct PhotoUploadTicket: Decodable {
    let uploadURL: String
    let contentType: String
    let maxContentLength: Int
}

private struct PhotoUploadRequest: Encodable {
    let contentType: String
    let contentLength: Int
}

private struct PhotoConfirmRequest: Encodable {
    let contentType: String
}

struct AuthorizeURLResponse: Decodable, Sendable {
    let authorizeUrl: String
    let redirectUri: String
}

private struct SocialLoginPayload: Encodable {
    let code: String
    let redirectUri: String
}

private struct AuthResponse: Decodable {
    let user: User
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
    case photoUploadRejected
    case photoUnavailable

    var errorDescription: String? {
        switch self {
        case .server(code: "ELEMENT_MINIMUM_REQUIRED"):
            "코스에는 요소가 1개 이상 필요해요."
        case .server(code: "COURSE_OWNER_ONLY"):
            "코스 작성자만 요소를 관리할 수 있어요."
        case .server(code: "PHOTO_TOO_LARGE"):
            "사진 용량이 너무 커요. 다른 사진을 선택해 주세요."
        case .server(code: "PHOTO_CONTENT_TYPE_UNSUPPORTED"):
            "이 형식의 사진은 올릴 수 없어요."
        case .server(code: "PHOTO_NOT_UPLOADED"):
            "사진 전송이 끝나지 않았어요. 다시 시도해 주세요."
        case .server(code: "PHOTO_STORAGE_UNAVAILABLE"):
            "사진 기능을 잠시 사용할 수 없어요. 나중에 다시 시도해 주세요."
        case .photoUploadRejected:
            "사진을 전송하지 못했어요. 다시 시도해 주세요."
        case .photoUnavailable:
            "사진을 불러오지 못했어요."
        case .invalidResponse, .server:
            "서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .unauthorized:
            "인증이 만료되었어요. 다시 시도해 주세요."
        case .invalidPayload:
            "코스 정보를 처리할 수 없어요. 다시 시도해 주세요."
        }
    }
}
