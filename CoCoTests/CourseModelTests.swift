import Foundation
import Testing
@testable import CoCo

struct CourseModelTests {
    @Test
    func decodesServerCourseJSON() throws {
        let json = """
        {
          "id": "10000000-0000-0000-0000-000000000001",
          "ownerId": "20000000-0000-0000-0000-000000000001",
          "ownerName": "노을러너",
          "name": "한강 노을 라인",
          "summary": "여의도 한강공원 노을 코스",
          "difficulty": "MODERATE",
          "locationLabel": "서울 영등포구",
          "distanceMeters": 5200,
          "estimatedDurationSeconds": 2520,
          "routeSource": "IMPORTED_GPX",
          "routePoints": [
            {"id": "11000000-0000-0000-0000-000000000001", "sequence": 0, "latitude": 37.52, "longitude": 126.93}
          ],
          "elements": [
            {"id": "12000000-0000-0000-0000-000000000001",
             "courseId": "10000000-0000-0000-0000-000000000001",
             "category": "CAUTION", "latitude": 37.52, "longitude": 126.93,
             "distanceFromStartMeters": 300, "title": "어두운 구간", "description": "야간 주의"}
          ],
          "scrapCount": 3,
          "reactionCounts": {"like": 2, "hard": 0, "scenic": 5},
          "isScrapped": true,
          "myReactions": ["SCENIC"]
        }
        """

        let course = try JSONDecoder().decode(Course.self, from: Data(json.utf8))

        #expect(course.name == "한강 노을 라인")
        #expect(course.difficulty == .moderate)
        #expect(course.routeSource == .importedGPX)
        #expect(course.routePoints.count == 1)
        #expect(course.elements.first?.category == .caution)
        #expect(course.reactionCounts.count(for: .scenic) == 5)
        #expect(course.isScrapped)
        #expect(course.myReactions == [.scenic])
    }

    @Test
    func scrapMutationIsIdempotentAndAdjustsCount() {
        var course = SeedData.courses[0]
        let initialCount = course.scrapCount

        course.setScrapped(true)
        course.setScrapped(true)
        #expect(course.isScrapped)
        #expect(course.scrapCount == initialCount + 1)

        course.setScrapped(false)
        #expect(!course.isScrapped)
        #expect(course.scrapCount == initialCount)
    }

    @Test
    func reactionMutationIsIdempotentAndAdjustsCount() {
        var course = SeedData.courses[0]
        let initialLikes = course.reactionCounts.count(for: .like)

        course.setReaction(.like, isOn: true)
        course.setReaction(.like, isOn: true)
        #expect(course.myReactions.contains(.like))
        #expect(course.reactionCounts.count(for: .like) == initialLikes + 1)

        course.setReaction(.like, isOn: false)
        #expect(!course.myReactions.contains(.like))
        #expect(course.reactionCounts.count(for: .like) == initialLikes)
    }

    @Test
    func upsertElementInsertsSortedByDistanceAndReplacesById() {
        var course = SeedData.courses[0]
        let elementID = UUID()

        let inserted = CourseElement(
            id: elementID,
            courseId: course.id,
            category: .facility,
            latitude: 37.5,
            longitude: 126.9,
            distanceFromStartMeters: 0,
            title: "출발점 화장실",
            description: "공중화장실"
        )
        course.upsertElement(inserted)

        #expect(course.elements.first?.id == elementID)

        let renamed = CourseElement(
            id: elementID,
            courseId: course.id,
            category: .facility,
            latitude: 37.5,
            longitude: 126.9,
            distanceFromStartMeters: 0,
            title: "고장난 화장실",
            description: "사용 불가"
        )
        let countBeforeReplace = course.elements.count
        course.upsertElement(renamed)

        #expect(course.elements.count == countBeforeReplace)
        #expect(course.elements.first?.title == "고장난 화장실")

        course.removeElement(id: elementID)
        #expect(!course.elements.contains { $0.id == elementID })
    }
}
