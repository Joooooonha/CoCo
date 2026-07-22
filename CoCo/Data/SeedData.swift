import Foundation

enum SeedData {
    static let courses = [hangangSunset, seoulForestRecovery]

    private static let hangangID = id("10000000-0000-0000-0000-000000000001")
    private static let seoulForestID = id("10000000-0000-0000-0000-000000000002")

    static let hangangSunset = Course(
        id: hangangID,
        ownerId: id("20000000-0000-0000-0000-000000000001"),
        ownerName: "노을러너",
        name: "한강 노을 라인",
        summary: "여의도 한강공원을 따라 노을과 강바람을 즐기는 코스",
        difficulty: .moderate,
        locationLabel: "서울 영등포구",
        distanceMeters: 5_200,
        estimatedDurationSeconds: 2_520,
        routeSource: .plannedMapKit,
        routePoints: [
            point("11000000-0000-0000-0000-000000000001", 0, 37.52852, 126.93275),
            point("11000000-0000-0000-0000-000000000002", 1, 37.52914, 126.92861),
            point("11000000-0000-0000-0000-000000000003", 2, 37.52873, 126.92418),
            point("11000000-0000-0000-0000-000000000004", 3, 37.52761, 126.91964),
            point("11000000-0000-0000-0000-000000000005", 4, 37.52652, 126.91524),
            point("11000000-0000-0000-0000-000000000006", 5, 37.52582, 126.91081)
        ],
        elements: [
            element(
                "12000000-0000-0000-0000-000000000001",
                courseID: hangangID,
                category: .view,
                latitude: 37.52873,
                longitude: 126.92418,
                distance: 1_800,
                title: "강변 노을 전망",
                description: "서쪽 시야가 열려 있어 해 질 무렵 경관이 좋은 구간이에요."
            ),
            element(
                "12000000-0000-0000-0000-000000000002",
                courseID: hangangID,
                category: .caution,
                latitude: 37.52761,
                longitude: 126.91964,
                distance: 3_100,
                title: "자전거 합류 구간",
                description: "자전거 도로와 가까워지는 구간이라 뒤쪽 통행을 확인해 주세요."
            ),
            element(
                "12000000-0000-0000-0000-000000000003",
                courseID: hangangID,
                category: .facility,
                latitude: 37.52652,
                longitude: 126.91524,
                distance: 4_200,
                title: "공원 화장실",
                description: "경로에서 짧게 벗어나 이용할 수 있는 공중화장실이 있어요."
            )
        ],
        scrapCount: 18,
        reactionCounts: ReactionCounts(like: 24, hard: 7, scenic: 31),
        isScrapped: false,
        myReactions: []
    )

    static let seoulForestRecovery = Course(
        id: seoulForestID,
        ownerId: id("20000000-0000-0000-0000-000000000002"),
        ownerName: "숲길메이트",
        name: "서울숲 리커버리 루프",
        summary: "서울숲 안쪽의 완만한 길을 한 바퀴 도는 가벼운 회복 코스",
        difficulty: .easy,
        locationLabel: "서울 성동구",
        distanceMeters: 3_800,
        estimatedDurationSeconds: 1_860,
        routeSource: .plannedMapKit,
        routePoints: [
            point("13000000-0000-0000-0000-000000000001", 0, 37.54437, 127.03742),
            point("13000000-0000-0000-0000-000000000002", 1, 37.54626, 127.03972),
            point("13000000-0000-0000-0000-000000000003", 2, 37.54851, 127.04123),
            point("13000000-0000-0000-0000-000000000004", 3, 37.54971, 127.03851),
            point("13000000-0000-0000-0000-000000000005", 4, 37.54742, 127.03584),
            point("13000000-0000-0000-0000-000000000006", 5, 37.54437, 127.03742)
        ],
        elements: [
            element(
                "14000000-0000-0000-0000-000000000001",
                courseID: seoulForestID,
                category: .facility,
                latitude: 37.54626,
                longitude: 127.03972,
                distance: 900,
                title: "음수대와 벤치",
                description: "잠깐 쉬거나 물을 마실 수 있는 공간이 경로 옆에 있어요."
            ),
            element(
                "14000000-0000-0000-0000-000000000002",
                courseID: seoulForestID,
                category: .view,
                latitude: 37.54971,
                longitude: 127.03851,
                distance: 2_200,
                title: "메타세쿼이아 길",
                description: "나무 사이로 이어지는 길이 계절마다 다른 분위기를 보여줘요."
            ),
            element(
                "14000000-0000-0000-0000-000000000003",
                courseID: seoulForestID,
                category: .caution,
                latitude: 37.54742,
                longitude: 127.03584,
                distance: 3_100,
                title: "보행자 밀집 구간",
                description: "주말에는 산책하는 사람이 많아 속도를 낮추는 편이 좋아요."
            )
        ],
        scrapCount: 11,
        reactionCounts: ReactionCounts(like: 19, hard: 2, scenic: 15),
        isScrapped: true,
        myReactions: [.like]
    )

    private static func point(
        _ idValue: String,
        _ sequence: Int,
        _ latitude: Double,
        _ longitude: Double
    ) -> RoutePoint {
        RoutePoint(
            id: id(idValue),
            sequence: sequence,
            latitude: latitude,
            longitude: longitude
        )
    }

    private static func element(
        _ idValue: String,
        courseID: UUID,
        category: ElementCategory,
        latitude: Double,
        longitude: Double,
        distance: Int,
        title: String,
        description: String
    ) -> CourseElement {
        CourseElement(
            id: id(idValue),
            courseId: courseID,
            category: category,
            latitude: latitude,
            longitude: longitude,
            distanceFromStartMeters: distance,
            title: title,
            description: description
        )
    }

    private static func id(_ value: String) -> UUID {
        guard let id = UUID(uuidString: value) else {
            preconditionFailure("Invalid seed UUID: \(value)")
        }
        return id
    }
}
