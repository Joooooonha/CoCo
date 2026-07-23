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
    private(set) var profileName: String? = CurrentUserName.value
    private(set) var profileErrorMessage: String?
    @ObservationIgnored private var isFetching = false
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
        guard !isFetching else { return }
        guard force || loadState == .idle || loadState == .empty else { return }

        isFetching = true
        defer { isFetching = false }

        // Refreshes keep showing current content instead of flashing a spinner.
        let hadContent = loadState == .loaded
        if !hadContent {
            loadState = .loading
        }

        do {
            async let scrapsRequest = apiClient.fetchMyScraps()
            async let myCoursesRequest = apiClient.fetchMyCourses()
            let (loadedScraps, loadedMyCourses) = try await (scrapsRequest, myCoursesRequest)
            guard !Task.isCancelled else {
                if !hadContent {
                    loadState = .idle
                }
                return
            }

            scraps = loadedScraps
            myCourses = loadedMyCourses
            profileName = CurrentUserName.value
            loadState = .loaded
        } catch is CancellationError {
            if !hadContent {
                loadState = .idle
            }
        } catch {
            // A failed silent refresh keeps the last shown content.
            if !hadContent {
                loadState = .failed(message: message(for: error))
            }
        }
    }

    func updateDisplayName(_ displayName: String) async -> Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 20 else {
            profileErrorMessage = "이름은 1~20자로 입력해 주세요."
            return false
        }

        profileErrorMessage = nil
        do {
            let user = try await apiClient.updateDisplayName(trimmedName)
            profileName = user.displayName
            await load(force: true)
            return true
        } catch {
            profileErrorMessage = "이름을 저장하지 못했어요. 다시 시도해 주세요."
            return false
        }
    }

    func clearProfileError() {
        profileErrorMessage = nil
    }

    private(set) var deleteErrorMessage: String?
    @ObservationIgnored private var isDeleting = false

    func deleteMyCourse(_ course: Course) async {
        guard !isDeleting else { return }

        isDeleting = true
        defer { isDeleting = false }
        deleteErrorMessage = nil

        do {
            try await apiClient.deleteCourse(courseID: course.id)
            myCourses.removeAll { $0.id == course.id }
            scraps.removeAll { $0.id == course.id }
        } catch {
            deleteErrorMessage = "코스를 삭제하지 못했어요. 다시 시도해 주세요."
        }
    }

    func clearDeleteError() {
        deleteErrorMessage = nil
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
