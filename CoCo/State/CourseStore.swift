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
    var isAddingElement = false
    private(set) var isSavingElement = false
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

    var isSelectedCourseMine: Bool {
        guard let selectedCourse, let currentUserID = CurrentUserID.value else { return false }
        return selectedCourse.ownerId == currentUserID
    }

    func toggleSelection(_ course: Course) {
        selectedCourseID = selectedCourseID == course.id ? nil : course.id
        selectedElement = nil
        isAddingElement = false
    }

    func showDetails(for element: CourseElement) {
        selectedElement = element
    }

    func dismissElementDetails() {
        selectedElement = nil
    }

    @ObservationIgnored private var isFetching = false

    func loadCourses(force: Bool = false) async {
        guard !isFetching else { return }
        guard force || loadState == .idle else { return }

        isFetching = true
        defer { isFetching = false }

        // Refreshes keep showing current content instead of flashing a spinner.
        let hadContent = loadState == .loaded
        if !hadContent {
            loadState = .loading
        }

        do {
            let loadedCourses = try await apiClient.fetchCourses()
            guard !Task.isCancelled else {
                if !hadContent {
                    loadState = .idle
                }
                return
            }

            courses = loadedCourses
            if let selectedCourseID, !courses.contains(where: { $0.id == selectedCourseID }) {
                self.selectedCourseID = nil
                selectedElement = nil
            }
            if let selectedElement,
               let refreshedElement = selectedCourse?.elements.first(where: { $0.id == selectedElement.id }) {
                self.selectedElement = refreshedElement
            }
            loadState = courses.isEmpty ? .empty : .loaded
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

    /// Saves a new or edited element on the owned course. Returns true on success.
    func saveElement(_ draft: ElementDraft, isNew: Bool, for courseID: Course.ID) async -> Bool {
        guard !isSavingElement else { return false }

        isSavingElement = true
        actionErrorMessage = nil
        defer { isSavingElement = false }

        let payload = CourseCreatePayload.ElementPayload(
            category: draft.category,
            latitude: draft.latitude,
            longitude: draft.longitude,
            distanceFromStartMeters: draft.distanceFromStartMeters,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let savedElement: CourseElement
            if isNew {
                savedElement = try await apiClient.addElement(courseID: courseID, payload)
            } else {
                savedElement = try await apiClient.updateElement(courseID: courseID, elementID: draft.id, payload)
            }
            updateCourse(id: courseID) { $0.upsertElement(savedElement) }
            if selectedElement?.id == savedElement.id {
                selectedElement = savedElement
            }
            isAddingElement = false
            return true
        } catch {
            actionErrorMessage = elementErrorMessage(for: error, fallback: "요소를 저장하지 못했어요. 다시 시도해 주세요.")
            return false
        }
    }

    func deleteElement(_ element: CourseElement) async {
        guard !isSavingElement else { return }

        isSavingElement = true
        actionErrorMessage = nil
        defer { isSavingElement = false }

        do {
            try await apiClient.deleteElement(courseID: element.courseId, elementID: element.id)
            updateCourse(id: element.courseId) { $0.removeElement(id: element.id) }
            if selectedElement?.id == element.id {
                selectedElement = nil
            }
        } catch {
            actionErrorMessage = elementErrorMessage(for: error, fallback: "요소를 삭제하지 못했어요. 다시 시도해 주세요.")
        }
    }

    private func elementErrorMessage(for error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return fallback
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
