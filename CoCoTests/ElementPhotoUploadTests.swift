import Foundation
import Testing

@testable import CoCo

/// Exercises the three-step upload against a stubbed network so the ordering
/// and the headers sent to storage are pinned down without a real bucket.
///
/// Serialized because `URLProtocol` subclasses are registered per process, so
/// the recorded calls are shared state that parallel tests would interleave.
@Suite(.serialized)
@MainActor
struct ElementPhotoUploadTests {
    private let courseID = UUID()
    private let elementID = UUID()

    @Test
    func uploadAsksForATicketThenSendsBytesThenConfirms() async throws {
        let photo = ElementPhotoProcessor.Output(
            data: Data(repeating: 0xAB, count: 1_024),
            contentType: "image/jpeg",
            pixelSize: CGSize(width: 800, height: 600)
        )
        StubURLProtocol.respond { request in
            if request.path.hasSuffix("/photo/upload-url") {
                return (200, Self.ticketJSON)
            }
            if request.path.hasPrefix("/upload/") {
                return (200, Data())
            }
            return (200, self.elementJSON())
        }

        let element = try await makeClient().uploadElementPhoto(
            courseID: courseID,
            elementID: elementID,
            photo: photo
        )

        let calls = StubURLProtocol.recorded
        #expect(calls.count == 3)

        #expect(calls[0].method == "POST")
        #expect(calls[0].path.hasSuffix("/photo/upload-url"))
        #expect(calls[0].authorization != nil)

        #expect(calls[1].method == "PUT")
        #expect(calls[1].path.hasPrefix("/upload/"))
        #expect(calls[1].body == photo.data)
        #expect(calls[1].contentType == "image/jpeg")
        // Storage must not receive the CoCo token; the signature is the whole
        // authorization for that request.
        #expect(calls[1].authorization == nil)

        #expect(calls[2].method == "PUT")
        #expect(calls[2].path.hasSuffix("/photo"))
        #expect(calls[2].authorization != nil)

        #expect(element.photoURL != nil)
        #expect(element.photoUploadedAt == "2026-08-17T12:50:07.123456Z")
    }

    /// If the bytes never land, confirming would attach a photo the server
    /// cannot verify. The upload has to stop at that point.
    @Test
    func aRejectedStorageUploadStopsBeforeConfirmation() async {
        StubURLProtocol.respond { request in
            if request.path.hasSuffix("/photo/upload-url") {
                return (200, Self.ticketJSON)
            }
            if request.path.hasPrefix("/upload/") {
                return (403, Data())
            }
            return (200, Data())
        }

        await #expect(throws: (any Error).self) {
            try await self.makeClient().uploadElementPhoto(
                courseID: self.courseID,
                elementID: self.elementID,
                photo: Self.samplePhoto
            )
        }

        let calls = StubURLProtocol.recorded
        #expect(calls.count == 2, "확정 요청까지 갔다면 서버가 검증할 수 없는 사진이 붙는다")
        #expect(calls.last?.path.hasPrefix("/upload/") == true)
    }

    @Test
    func aRejectedTicketNeverTouchesStorage() async {
        StubURLProtocol.respond { _ in
            (413, Data(#"{"code":"PHOTO_TOO_LARGE"}"#.utf8))
        }

        var message: String?
        do {
            _ = try await makeClient().uploadElementPhoto(
                courseID: courseID,
                elementID: elementID,
                photo: Self.samplePhoto
            )
        } catch {
            message = error.localizedDescription
        }

        #expect(message == "사진 용량이 너무 커요. 다른 사진을 선택해 주세요.")
        #expect(StubURLProtocol.recorded.count == 1)
    }

    @Test
    func storageUnavailableIsExplainedRatherThanShownAsAGenericFailure() async {
        StubURLProtocol.respond { _ in
            (503, Data(#"{"code":"PHOTO_STORAGE_UNAVAILABLE"}"#.utf8))
        }

        var message: String?
        do {
            _ = try await makeClient().uploadElementPhoto(
                courseID: courseID,
                elementID: elementID,
                photo: Self.samplePhoto
            )
        } catch {
            message = error.localizedDescription
        }

        #expect(message == "사진 기능을 잠시 사용할 수 없어요. 나중에 다시 시도해 주세요.")
    }

    @Test
    func deletingAPhotoUsesTheCoCoTokenAndNotStorage() async throws {
        StubURLProtocol.respond { _ in (204, Data()) }

        try await makeClient().deleteElementPhoto(courseID: courseID, elementID: elementID)

        let calls = StubURLProtocol.recorded
        #expect(calls.count == 1)
        #expect(calls[0].method == "DELETE")
        #expect(calls[0].path.hasSuffix("/photo"))
        #expect(calls[0].authorization != nil)
    }

    // MARK: - Support

    private static let samplePhoto = ElementPhotoProcessor.Output(
        data: Data(repeating: 0x01, count: 64),
        contentType: "image/jpeg",
        pixelSize: CGSize(width: 10, height: 10)
    )

    private static let ticketJSON = Data("""
        {"uploadURL":"https://storage.test/upload/courses/a/elements/b.jpg?X-Amz-Signature=abc",
         "contentType":"image/jpeg","maxContentLength":5242880}
        """.utf8)

    private func elementJSON() -> Data {
        Data("""
            {"id":"\(elementID.uuidString)","courseId":"\(courseID.uuidString)","category":"VIEW",
             "latitude":37.5,"longitude":126.9,"distanceFromStartMeters":400,
             "title":"강변 전망","description":"노을이 잘 보이는 구간",
             "photoURL":"https://storage.test/read/courses/a/elements/b.jpg?X-Amz-Signature=def",
             "photoUploadedAt":"2026-08-17T12:50:07.123456Z"}
            """.utf8)
    }

    /// A per-test keychain service keeps these from reading or clobbering the
    /// token a running simulator session is using.
    private func makeClient() -> CourseAPIClient {
        let tokenStore = KeychainTokenStore(service: "CoCoTests.\(UUID().uuidString)")
        try? tokenStore.save("test-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return CourseAPIClient(
            baseURL: URL(string: "https://api.test")!,
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
    }
}

/// Records what the client sent and replays canned responses.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Call {
        let method: String
        let path: String
        let body: Data?
        let authorization: String?
        let contentType: String?
    }

    private struct State {
        var handler: ((Call) -> (Int, Data))?
        var recorded: [Call] = []
    }

    nonisolated(unsafe) private static var state = State()
    private static let lock = NSLock()

    /// Installing a responder also clears the recorded calls, so a test never
    /// has to remember to reset first.
    static func respond(_ handler: @escaping (Call) -> (Int, Data)) {
        lock.withLock { state = State(handler: handler) }
    }

    static var recorded: [Call] {
        lock.withLock { state.recorded }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let call = Call(
            method: request.httpMethod ?? "GET",
            path: request.url?.path ?? "",
            // URLSession turns an upload body into a stream before it reaches
            // here, so reading `httpBody` alone would always come up empty.
            body: request.httpBody ?? request.httpBodyStream.map(Self.drain),
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            contentType: request.value(forHTTPHeaderField: "Content-Type")
        )

        let (statusCode, body) = Self.lock.withLock { () -> (Int, Data) in
            Self.state.recorded.append(call)
            return Self.state.handler?(call) ?? (200, Data())
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func drain(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4_096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
