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
