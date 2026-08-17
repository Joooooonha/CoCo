import CoreLocation
import Foundation
import Testing
@testable import CoCo

/// Records how many legs were requested so tests can prove that resolved legs
/// are reused instead of recalculated.
actor CountingRouteCalculator: WalkingRouteCalculator {
    private(set) var callCount = 0
    private(set) var requestedPairs: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []

    func calculateSegment(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RouteSegment {
        callCount += 1
        requestedPairs.append((origin, destination))

        // A straight two-point leg is enough; the planner only merges what it gets.
        let distance = MKMapPointDistance(origin, destination)
        return RouteSegment(
            coordinates: [origin, destination],
            distanceMeters: distance,
            durationSeconds: distance / 1.25
        )
    }
}

private func MKMapPointDistance(
    _ lhs: CLLocationCoordinate2D,
    _ rhs: CLLocationCoordinate2D
) -> Double {
    CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
        .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
}

@MainActor
struct RouteSegmentCachingTests {
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
    func eachLegIsRequestedOnlyOnce() async {
        let calculator = CountingRouteCalculator()
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(6, to: planner)

        // Six waypoints make five legs. Without caching this would have been
        // 1+2+3+4+5 = 15 requests.
        #expect(await calculator.callCount == 5)
        #expect(planner.routeState.plannedRoute != nil)
    }

    @Test
    func removingAWaypointCostsNoRequest() async {
        let calculator = CountingRouteCalculator()
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(4, to: planner)
        let afterAdding = await calculator.callCount

        planner.removeLastWaypoint()
        await planner.waitForRouteCalculation()

        #expect(await calculator.callCount == afterAdding)
        #expect(planner.waypoints.count == 3)
    }

    @Test
    func reAddingAWaypointRequestsOnlyTheNewLeg() async {
        let calculator = CountingRouteCalculator()
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(4, to: planner)
        planner.removeLastWaypoint()
        await planner.waitForRouteCalculation()

        planner.addWaypoint(coordinate(9))
        await planner.waitForRouteCalculation()

        // Three legs from the first pass plus one for the replacement waypoint.
        #expect(await calculator.callCount == 4)
    }

    @Test
    func closingTheLoopAddsOneLeg() async {
        let calculator = CountingRouteCalculator()
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(3, to: planner)
        let beforeClosing = await calculator.callCount

        planner.closeLoopToStart()
        await planner.waitForRouteCalculation()

        #expect(await calculator.callCount == beforeClosing + 1)
        #expect(planner.isClosedLoop)
    }

    @Test
    func clearingDropsEveryCachedLeg() async {
        let calculator = CountingRouteCalculator()
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(3, to: planner)
        planner.clearRoute()

        #expect(planner.routeState == .idle)
        #expect(planner.waypoints.isEmpty)

        // A fresh plan has to resolve its legs again.
        await addWaypoints(2, to: planner)
        #expect(await calculator.callCount == 3)
    }

    @Test
    func mergedRouteCoversEveryLeg() async {
        let calculator = CountingRouteCalculator()
        let planner = RoutePlannerStore(calculator: calculator)

        await addWaypoints(4, to: planner)

        let route = planner.routeState.plannedRoute
        // Three legs of two points each, sharing endpoints: 2 + 1 + 1.
        #expect(route?.coordinates.count == 4)
        #expect(route?.cumulativeMeters.count == 4)
        #expect((route?.distanceMeters ?? 0) > 0)
        // Cumulative distance has to increase along the route.
        #expect((route?.cumulativeMeters.first ?? 1) == 0)
        #expect((route?.cumulativeMeters.last ?? 0) > 0)
    }
}
