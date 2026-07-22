import Foundation
import Observation

@Observable
final class CourseStore {
    let courses: [Course]
    var selectedCourseID: Course.ID?
    var selectedElement: CourseElement?

    init(
        courses: [Course] = SeedData.courses,
        selectedCourseID: Course.ID? = nil,
        selectedElement: CourseElement? = nil
    ) {
        self.courses = courses
        self.selectedCourseID = selectedCourseID
        self.selectedElement = selectedElement
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
}
