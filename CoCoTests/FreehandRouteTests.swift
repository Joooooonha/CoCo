import CoreLocation
import Foundation
import Testing
@testable import CoCo

@MainActor
struct FreehandRouteTests {
    /// A stroke heading north; 0.001 latitude is roughly 111 m.
    private func stroke(from startIndex: Int, count: Int) -> [CLLocationCoordinate2D] {
        (0..<count).map { offset in
            CLLocationCoordinate2D(
                latitude: 37.55 + Double(startIndex + offset) * 0.001,
                longitude: 126.98
            )
        }
    }

    private func freehandPlanner() -> RoutePlannerStore {
        let planner = RoutePlannerStore(calculator: CountingRouteCalculator())
        planner.setMode(.freehand)
        return planner
    }

    @Test
    func drawnStrokeBecomesARouteWithoutAnyRequest() async {
        let calculator = CountingRouteCalculator()
        let planner = RoutePlannerStore(calculator: calculator)
        planner.setMode(.freehand)

        planner.appendDrawnStroke(stroke(from: 0, count: 5))

        // Drawing never asks the routing service for anything.
        #expect(await calculator.callCount == 0)
        #expect(planner.routeOrigin == .drawnFreehand)
        #expect(planner.routeState.plannedRoute?.coordinates.count == 5)
        #expect(planner.canContinueToDetails)
    }

    @Test
    func distanceAndDurationComeFromTheDrawnLine() {
        let planner = freehandPlanner()

        // Four points spaced ~111 m apart is roughly 333 m of line.
        planner.appendDrawnStroke(stroke(from: 0, count: 4))

        let route = planner.routeState.plannedRoute
        let distance = route?.distanceMeters ?? 0
        #expect(distance > 300 && distance < 360)

        // Duration is the distance at an average walking pace of 1.25 m/s.
        let expectedSeconds = Int((Double(distance) / 1.25).rounded())
        #expect(route?.durationSeconds == max(60, expectedSeconds))
    }

    @Test
    func strokesAccumulateSoTheMapCanBePannedBetweenThem() {
        let planner = freehandPlanner()

        planner.appendDrawnStroke(stroke(from: 0, count: 3))
        let afterFirst = planner.routeState.plannedRoute?.coordinates.count ?? 0

        planner.appendDrawnStroke(stroke(from: 10, count: 3))

        #expect(planner.drawnStrokes.count == 2)
        #expect(planner.routeState.plannedRoute?.coordinates.count == afterFirst + 3)
    }

    @Test
    func undoRemovesOnlyTheLastStroke() {
        let planner = freehandPlanner()

        planner.appendDrawnStroke(stroke(from: 0, count: 3))
        planner.appendDrawnStroke(stroke(from: 10, count: 3))
        planner.undoLastStroke()

        #expect(planner.drawnStrokes.count == 1)
        #expect(planner.routeState.plannedRoute?.coordinates.count == 3)

        // Undoing the last remaining stroke returns to an empty plan.
        planner.undoLastStroke()
        #expect(planner.drawnStrokes.isEmpty)
        #expect(planner.routeState == .idle)
        #expect(planner.routeOrigin == .mapKitPlanning)
    }

    @Test
    func aStrokeTooShortToBeARouteIsIgnored() {
        let planner = freehandPlanner()

        planner.appendDrawnStroke([CLLocationCoordinate2D(latitude: 37.55, longitude: 126.98)])

        #expect(planner.drawnStrokes.isEmpty)
        #expect(planner.routeState == .idle)
    }

    @Test
    func waypointTapsAreIgnoredWhileDrawing() {
        let planner = freehandPlanner()

        planner.addWaypoint(CLLocationCoordinate2D(latitude: 37.55, longitude: 126.98))

        #expect(planner.waypoints.isEmpty)
        #expect(!planner.canAddWaypoint)
    }

    @Test
    func switchingModesStartsFromAnEmptyPlan() {
        let planner = freehandPlanner()
        planner.appendDrawnStroke(stroke(from: 0, count: 4))
        #expect(planner.hasPlanningContent)

        planner.setMode(.waypoints)

        // The two modes are exclusive, so the drawn route does not linger.
        #expect(planner.drawnStrokes.isEmpty)
        #expect(planner.routeState == .idle)
        #expect(planner.routeOrigin == .mapKitPlanning)
        #expect(planner.mode == .waypoints)
    }

    @Test
    func freehandRouteIsSubmittedAsDrawnFreehand() {
        #expect(RouteOrigin.drawnFreehand.routeSource == .drawnFreehand)
        #expect(RouteOrigin.importedGPX.routeSource == .importedGPX)
        #expect(RouteOrigin.mapKitPlanning.routeSource == .plannedMapKit)
    }

    @Test
    func elementsSnapToTheDrawnLine() {
        let planner = freehandPlanner()
        planner.appendDrawnStroke(stroke(from: 0, count: 5))

        let snapped = planner.nearestRoutePoint(
            to: CLLocationCoordinate2D(latitude: 37.5521, longitude: 126.9805)
        )

        #expect(snapped != nil)
        #expect(snapped?.coordinate.latitude == 37.552)
        #expect((snapped?.distanceFromStartMeters ?? 0) > 0)
    }
}
