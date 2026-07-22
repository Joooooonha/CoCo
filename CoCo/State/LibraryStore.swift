import Foundation
import Observation

enum LibrarySegment: String, CaseIterable, Identifiable {
    case scraps
    case myCourses

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .scraps: "스크랩"
        case .myCourses: "내 코스"
        }
    }
}

@Observable
final class LibraryStore {
    var segment: LibrarySegment = .scraps
    private(set) var scraps: [Course] = []
    private(set) var myCourses: [Course] = []
    private(set) var loadState: CourseLoadState = .idle
    @ObservationIgnored private let apiClient: CourseAPIClient

    init(
        scraps: [Course] = [],
        myCourses: [Course] = [],
        apiClient: CourseAPIClient = CourseAPIClient()
    ) {
        self.scraps = scraps
        self.myCourses = myCourses
        if !scraps.isEmpty || !myCourses.isEmpty {
            loadState = .loaded
        }
        self.apiClient = apiClient
    }

    var courses: [Course] {
        switch segment {
        case .scraps: scraps
        case .myCourses: myCourses
        }
    }

    func load(force: Bool = false) async {
        guard loadState != .loading else { return }
        guard force || loadState == .idle || loadState == .empty else { return }

        loadState = .loading

        do {
            async let scrapsRequest = apiClient.fetchMyScraps()
            async let myCoursesRequest = apiClient.fetchMyCourses()
            let (loadedScraps, loadedMyCourses) = try await (scrapsRequest, myCoursesRequest)
            guard !Task.isCancelled else {
                loadState = .idle
                return
            }

            scraps = loadedScraps
            myCourses = loadedMyCourses
            loadState = .loaded
        } catch is CancellationError {
            loadState = .idle
        } catch {
            loadState = .failed(message: message(for: error))
        }
    }

    private func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "인터넷 연결을 확인하고 다시 시도해 주세요."
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return "서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요."
            default:
                break
            }
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return "보관함을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
    }
}
