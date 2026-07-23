import CoreLocation
import Foundation
import Testing
@testable import CoCo

@MainActor
struct RoutePlannerStoreTests {
    private func importedRoute(
        coordinates: [CLLocationCoordinate2D],
        distanceMeters: Int? = nil,
        durationSeconds: Int? = nil
    ) -> GPXRoute {
        GPXRoute(
            name: nil,
            coordinates: coordinates,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds
        )
    }

    @Test
    func waypointLimitAndLoopClosing() {
        let planner = RoutePlannerStore()

        for index in 0..<10 {
            planner.addWaypoint(CLLocationCoordinate2D(latitude: 37.5 + Double(index) * 0.001, longitude: 127.0))
        }
        #expect(planner.waypoints.count == RoutePlannerStore.maximumWaypoints)

        planner.removeLastWaypoint()
        planner.closeLoopToStart()
        #expect(planner.isClosedLoop)
        #expect(planner.waypoints.last?.latitude == planner.waypoints.first?.latitude)
    }

    @Test
    func importedRouteUsesMetadataAndEnablesContinuation() {
        let planner = RoutePlannerStore()
        planner.loadImportedRoute(importedRoute(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.55, longitude: 126.98),
                CLLocationCoordinate2D(latitude: 37.56, longitude: 126.99)
            ],
            distanceMeters: 4455,
            durationSeconds: 5194
        ))

        #expect(planner.routeOrigin == .importedGPX)
        #expect(planner.routeState.plannedRoute?.distanceMeters == 4455)
        #expect(planner.routeState.plannedRoute?.durationSeconds == 5194)
        #expect(planner.canContinueToDetails)
        #expect(!planner.canAddWaypoint)
    }

    @Test
    func importedRouteWithoutMetadataDerivesDistanceAndDuration() {
        let planner = RoutePlannerStore()
        // Roughly 1.11 km of northward movement.
        planner.loadImportedRoute(importedRoute(coordinates: [
            CLLocationCoordinate2D(latitude: 37.55, longitude: 126.98),
            CLLocationCoordinate2D(latitude: 37.56, longitude: 126.98)
        ]))

        let route = try? #require(planner.routeState.plannedRoute)
        let distance = route?.distanceMeters ?? 0
        #expect(distance > 1_000 && distance < 1_250)

        // Fallback duration assumes a 1.25 m/s walking pace.
        let expectedDuration = Int((Double(distance) / 1.25).rounded())
        #expect(route?.durationSeconds == expectedDuration)
    }

    @Test
    func nearestRoutePointSnapsToVertexWithCumulativeDistance() {
        let planner = RoutePlannerStore()
        planner.loadImportedRoute(importedRoute(coordinates: [
            CLLocationCoordinate2D(latitude: 37.55, longitude: 126.98),
            CLLocationCoordinate2D(latitude: 37.56, longitude: 126.98),
            CLLocationCoordinate2D(latitude: 37.57, longitude: 126.98)
        ]))

        let snapped = planner.nearestRoutePoint(
            to: CLLocationCoordinate2D(latitude: 37.5601, longitude: 126.9805)
        )

        #expect(snapped?.coordinate.latitude == 37.56)
        let midpointDistance = snapped?.distanceFromStartMeters ?? 0
        #expect(midpointDistance > 1_000 && midpointDistance < 1_250)
    }

    @Test
    func clearingImportedRouteReturnsToTapPlanning() {
        let planner = RoutePlannerStore()
        planner.loadImportedRoute(importedRoute(coordinates: [
            CLLocationCoordinate2D(latitude: 37.55, longitude: 126.98),
            CLLocationCoordinate2D(latitude: 37.56, longitude: 126.98)
        ]))
        #expect(planner.hasPlanningContent)

        planner.clearRoute()

        #expect(planner.routeOrigin == .mapKitPlanning)
        #expect(planner.routeState == .idle)
        #expect(!planner.hasPlanningContent)
        #expect(!planner.canContinueToDetails)
    }

    @Test
    func submissionRequiresNameSummaryAndElements() {
        let planner = RoutePlannerStore()
        planner.loadImportedRoute(importedRoute(coordinates: [
            CLLocationCoordinate2D(latitude: 37.55, longitude: 126.98),
            CLLocationCoordinate2D(latitude: 37.56, longitude: 126.98)
        ]))

        #expect(!planner.canSubmit)

        planner.courseName = "테스트 코스"
        planner.courseSummary = "테스트 설명"
        #expect(!planner.canSubmit)

        planner.elementDrafts.append(ElementDraft(
            id: UUID(),
            category: .view,
            latitude: 37.55,
            longitude: 126.98,
            distanceFromStartMeters: 0,
            title: "전망",
            description: "설명"
        ))
        #expect(planner.canSubmit)
    }
}
