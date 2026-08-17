import CoreLocation
import Foundation
import Testing
@testable import CoCo

/// Fails the legs whose start latitude is listed, so tests can target one leg.
actor SelectiveFailureCalculator: WalkingRouteCalculator {
    private(set) var callCount = 0
    private var failingOrigins: Set<String>

    init(failingOrigins: Set<String> = []) {
        self.failingOrigins = failingOrigins
    }

    func stopFailing() {
        failingOrigins = []
    }

    func calculateSegment(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RouteSegment {
        callCount += 1

        if failingOrigins.contains(Self.key(origin)) {
            throw URLError(.cannotFindHost)
        }

        let distance = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        return RouteSegment(
            coordinates: [origin, destination],
            distanceMeters: distance,
            durationSeconds: distance / 1.25
        )
    }

    static func key(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f", coordinate.latitude)
    }
}

@MainActor
struct RouteSegmentFailureTests {
    private func coordinate(_ index: Int) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 37.55 + Double(index) * 0.002, longitude: 126.98)
    }

    private func addWaypoints(_ count: Int, to planner: RoutePlannerStore) async {
        for index in 0..<count {
            planner.addWaypoint(coordinate(index))
            await planner.waitForRouteCalculation()
        }
    }

    @Test
    func oneFailedLegDoesNotDiscardTheOthers() async {
        // The leg starting at the second waypoint always fails.
        let calculator = SelectiveFailureCalculator(
            failingOrigins: [SelectiveFailureCalculator.key(coordinate(1))]
        )
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(4, to: planner)

        // Three legs: the first and third resolve, the middle one fails.
        #expect(planner.totalSegmentCount == 3)
        #expect(planner.resolvedSegmentCount == 2)
        #expect(planner.failedConnections.count == 1)

        // The route is not submittable, but the resolved parts remain drawable.
        #expect(planner.routeState.plannedRoute == nil)
        #expect(!planner.canContinueToDetails)
        #expect(planner.resolvedPolylines.count == 2)
    }

    @Test
    func failedLegIsRetriedSeveralTimesBeforeGivingUp() async {
        let calculator = SelectiveFailureCalculator(
            failingOrigins: [SelectiveFailureCalculator.key(coordinate(0))]
        )
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(2, to: planner)

        // A single leg that keeps failing is attempted more than once.
        #expect(await calculator.callCount > 1)
        #expect(planner.failedConnections.count == 1)
    }

    @Test
    func retryOnlyRerequestsTheFailedLeg() async {
        let calculator = SelectiveFailureCalculator(
            failingOrigins: [SelectiveFailureCalculator.key(coordinate(1))]
        )
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(4, to: planner)
        let callsAfterFirstPass = await calculator.callCount

        await calculator.stopFailing()
        planner.retryRouteCalculation()
        await planner.waitForRouteCalculation()

        // Only the previously failed leg was requested again.
        #expect(await calculator.callCount == callsAfterFirstPass + 1)
        #expect(planner.resolvedSegmentCount == 3)
        #expect(planner.failedConnections.isEmpty)
        #expect(planner.routeState.plannedRoute != nil)
        #expect(planner.canContinueToDetails)
    }

    @Test
    func removingTheProblemWaypointClearsTheFailure() async {
        let calculator = SelectiveFailureCalculator(
            failingOrigins: [SelectiveFailureCalculator.key(coordinate(2))]
        )
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(4, to: planner)
        #expect(planner.failedConnections.count == 1)

        // Dropping the last waypoint removes the leg that could not be resolved.
        planner.removeLastWaypoint()
        await planner.waitForRouteCalculation()

        #expect(planner.failedConnections.isEmpty)
        #expect(planner.routeState.plannedRoute != nil)
    }

    @Test
    func resolvedPolylinesSplitAroundAFailedLeg() async {
        let calculator = SelectiveFailureCalculator(
            failingOrigins: [SelectiveFailureCalculator.key(coordinate(1))]
        )
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(4, to: planner)

        // Two separate runs rather than one line bridging the gap, so the map
        // never implies a path that was not resolved.
        let polylines = planner.resolvedPolylines
        #expect(polylines.count == 2)
        #expect(polylines.allSatisfy { $0.count >= 2 })
    }
}
