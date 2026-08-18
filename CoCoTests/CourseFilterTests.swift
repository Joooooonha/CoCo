import Foundation
import Testing
@testable import CoCo

@MainActor
struct CourseFilterTests {
    private static let seoulViewport = MapViewport(
        minLatitude: 37.4, maxLatitude: 37.7, minLongitude: 126.8, maxLongitude: 127.2
    )
    private static let daeguViewport = MapViewport(
        minLatitude: 35.7, maxLatitude: 36.0, minLongitude: 128.4, maxLongitude: 128.8
    )

    @Test
    func viewportFilterKeepsOnlyOverlappingCourses() {
        let store = CourseStore(courses: SeedData.courses)

        store.visibleViewport = Self.seoulViewport
        #expect(store.visibleCourses.count == SeedData.courses.count)

        store.visibleViewport = Self.daeguViewport
        #expect(store.visibleCourses.isEmpty)
    }

    @Test
    func selectedCourseStaysVisibleOutsideViewport() {
        let store = CourseStore(courses: SeedData.courses)
        store.selectedCourseID = SeedData.courses[0].id

        store.visibleViewport = Self.daeguViewport

        #expect(store.visibleCourses.map(\.id) == [SeedData.courses[0].id])
    }

    @Test
    func searchFiltersByNameLocationAndOwner() {
        let store = CourseStore(courses: SeedData.courses)

        store.searchText = "노을"
        #expect(store.visibleCourses.count == 1)
        #expect(store.visibleCourses.first?.name.contains("노을") == true)

        store.searchText = "성동구"
        #expect(store.visibleCourses.count == 1)

        store.searchText = "없는 검색어"
        #expect(store.visibleCourses.isEmpty)

        store.searchText = "   "
        #expect(store.visibleCourses.count == SeedData.courses.count)
    }

    @Test
    func viewportAndSearchCombine() {
        let store = CourseStore(courses: SeedData.courses)

        store.visibleViewport = Self.seoulViewport
        store.searchText = "숲길메이트"

        #expect(store.visibleCourses.count == 1)
        #expect(store.visibleCourses.first?.ownerName == "숲길메이트")
    }
}

/// Selecting a different course must not leave the previous course's element
/// on screen. This regressed once because each caller cleared it by hand.
@MainActor
struct CourseSelectionTests {
    @Test
    func changingTheSelectedCourseDropsTheElementDetail() {
        let store = CourseStore(courses: SeedData.courses)
        let first = SeedData.courses[0]
        let second = SeedData.courses[1]

        store.selectedCourseID = first.id
        store.showDetails(for: first.elements[0])
        store.isAddingElement = true

        store.selectedCourseID = second.id

        #expect(store.selectedElement == nil)
        #expect(!store.isAddingElement)
    }

    @Test
    func reselectingTheSameCourseKeepsTheElementDetail() {
        let store = CourseStore(courses: SeedData.courses)
        let course = SeedData.courses[0]
        store.selectedCourseID = course.id
        store.showDetails(for: course.elements[0])

        store.selectedCourseID = course.id

        #expect(store.selectedElement != nil)
    }

    @Test
    func deselectingClearsTheElementDetail() {
        let store = CourseStore(courses: SeedData.courses)
        let course = SeedData.courses[0]
        store.selectedCourseID = course.id
        store.showDetails(for: course.elements[0])

        store.toggleSelection(course)

        #expect(store.selectedCourseID == nil)
        #expect(store.selectedElement == nil)
    }
}
