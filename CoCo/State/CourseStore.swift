import Foundation
import Observation

enum CourseLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(message: String)
}

@Observable
final class CourseStore {
    private(set) var courses: [Course]
    private(set) var loadState: CourseLoadState
    private(set) var pendingScrapCourseIDs: Set<Course.ID> = []
    private(set) var pendingReactionKeys: Set<String> = []
    private(set) var actionErrorMessage: String?
    var selectedCourseID: Course.ID?
    var selectedElement: CourseElement?
    @ObservationIgnored private let apiClient: CourseAPIClient

    init(
        courses: [Course] = [],
        selectedCourseID: Course.ID? = nil,
        selectedElement: CourseElement? = nil,
        apiClient: CourseAPIClient = CourseAPIClient()
    ) {
        self.courses = courses
        self.loadState = courses.isEmpty ? .idle : .loaded
        self.selectedCourseID = selectedCourseID
        self.selectedElement = selectedElement
        self.apiClient = apiClient
    }

    var selectedCourse: Course? {
        courses.first { $0.id == selectedCourseID }
    }

    func toggleSelection(_ course: Course) {
        selectedCourseID = selectedCourseID == course.id ? nil : course.id
        selectedElement = nil
    }

    func showDetails(for element: CourseElement) {
        selectedElement = element
    }

    func dismissElementDetails() {
        selectedElement = nil
    }

    func loadCourses(force: Bool = false) async {
        guard loadState != .loading else { return }
        guard force || loadState == .idle else { return }

        loadState = .loading

        do {
            let loadedCourses = try await apiClient.fetchCourses()
            guard !Task.isCancelled else {
                loadState = .idle
                return
            }

            courses = loadedCourses
            if let selectedCourseID, !courses.contains(where: { $0.id == selectedCourseID }) {
                self.selectedCourseID = nil
                selectedElement = nil
            }
            loadState = courses.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            loadState = .idle
        } catch {
            loadState = .failed(message: message(for: error))
        }
    }

    func isReactionPending(_ type: ReactionType, for courseID: Course.ID) -> Bool {
        pendingReactionKeys.contains(reactionKey(type, for: courseID))
    }

    func toggleScrap(for course: Course) async {
        guard !pendingScrapCourseIDs.contains(course.id) else { return }

        let targetValue = !course.isScrapped
        pendingScrapCourseIDs.insert(course.id)
        actionErrorMessage = nil
        updateCourse(id: course.id) { $0.setScrapped(targetValue) }

        do {
            try await apiClient.updateScrap(courseID: course.id, isScrapped: targetValue)
        } catch {
            updateCourse(id: course.id) { $0.setScrapped(!targetValue) }
            actionErrorMessage = "스크랩을 저장하지 못했어요. 다시 시도해 주세요."
        }
        pendingScrapCourseIDs.remove(course.id)
    }

    func toggleReaction(_ type: ReactionType, for course: Course) async {
        let key = reactionKey(type, for: course.id)
        guard !pendingReactionKeys.contains(key) else { return }

        let targetValue = !course.myReactions.contains(type)
        pendingReactionKeys.insert(key)
        actionErrorMessage = nil
        updateCourse(id: course.id) { $0.setReaction(type, isOn: targetValue) }

        do {
            try await apiClient.updateReaction(courseID: course.id, type: type, isOn: targetValue)
        } catch {
            updateCourse(id: course.id) { $0.setReaction(type, isOn: !targetValue) }
            actionErrorMessage = "반응을 저장하지 못했어요. 다시 시도해 주세요."
        }
        pendingReactionKeys.remove(key)
    }

    private func updateCourse(id: Course.ID, _ transform: (inout Course) -> Void) {
        guard let index = courses.firstIndex(where: { $0.id == id }) else { return }
        transform(&courses[index])
    }

    private func reactionKey(_ type: ReactionType, for courseID: Course.ID) -> String {
        "\(courseID.uuidString)-\(type.rawValue)"
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
        return "코스를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
    }
}
