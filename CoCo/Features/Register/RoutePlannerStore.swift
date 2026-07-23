import Foundation
import MapKit
import Observation

struct PlannedRoute: Equatable {
    let coordinates: [CLLocationCoordinate2D]
    let cumulativeMeters: [Double]
    let distanceMeters: Int
    let durationSeconds: Int

    static func == (lhs: PlannedRoute, rhs: PlannedRoute) -> Bool {
        lhs.distanceMeters == rhs.distanceMeters
            && lhs.durationSeconds == rhs.durationSeconds
            && lhs.coordinates.count == rhs.coordinates.count
    }
}

enum RoutePlanState: Equatable {
    case idle
    case calculating
    case ready(PlannedRoute)
    case failed(message: String)

    var plannedRoute: PlannedRoute? {
        if case .ready(let route) = self {
            return route
        }
        return nil
    }
}

struct ElementDraft: Identifiable, Equatable {
    let id: UUID
    var category: ElementCategory
    var latitude: Double
    var longitude: Double
    var distanceFromStartMeters: Int
    var title: String
    var description: String
}

@MainActor
@Observable
final class RoutePlannerStore {
    static let maximumWaypoints = 7

    private(set) var waypoints: [CLLocationCoordinate2D] = []
    private(set) var routeState: RoutePlanState = .idle
    var elementDrafts: [ElementDraft] = []
    var courseName = ""
    var courseSummary = ""
    var difficulty: CourseDifficulty = .moderate
    private(set) var isSubmitting = false
    private(set) var submissionErrorMessage: String?
    @ObservationIgnored private var routeTask: Task<Void, Never>?
    @ObservationIgnored private let apiClient: CourseAPIClient

    init(apiClient: CourseAPIClient = CourseAPIClient()) {
        self.apiClient = apiClient
    }

    var canAddWaypoint: Bool {
        waypoints.count < Self.maximumWaypoints
    }

    var canContinueToDetails: Bool {
        waypoints.count >= 2 && routeState.plannedRoute != nil
    }

    var isClosedLoop: Bool {
        guard let first = waypoints.first, let last = waypoints.last, waypoints.count >= 2 else { return false }
        return abs(first.latitude - last.latitude) < 0.000_01
            && abs(first.longitude - last.longitude) < 0.000_01
    }

    var nextTapDescription: String {
        switch waypoints.count {
        case 0: "지도를 탭해 출발지를 선택하세요"
        case Self.maximumWaypoints...: "지점은 최대 \(Self.maximumWaypoints)개까지 선택할 수 있어요"
        default: "지도를 탭해 경유지나 도착지를 추가하세요"
        }
    }

    func addWaypoint(_ coordinate: CLLocationCoordinate2D) {
        guard canAddWaypoint else { return }
        waypoints.append(coordinate)
        recalculateRoute()
    }

    func closeLoopToStart() {
        guard let start = waypoints.first, waypoints.count >= 2, !isClosedLoop, canAddWaypoint else { return }
        waypoints.append(start)
        recalculateRoute()
    }

    func removeLastWaypoint() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        recalculateRoute()
    }

    func clearRoute() {
        waypoints.removeAll()
        elementDrafts.removeAll()
        routeTask?.cancel()
        routeState = .idle
    }

    func resetAll() {
        clearRoute()
        courseName = ""
        courseSummary = ""
        difficulty = .moderate
        submissionErrorMessage = nil
    }

    func retryRouteCalculation() {
        recalculateRoute()
    }

    var canSubmit: Bool {
        routeState.plannedRoute != nil
            && !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !courseSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !elementDrafts.isEmpty
            && !isSubmitting
    }

    func nearestRoutePoint(to coordinate: CLLocationCoordinate2D) -> (coordinate: CLLocationCoordinate2D, distanceFromStartMeters: Int)? {
        guard let route = routeState.plannedRoute, !route.coordinates.isEmpty else { return nil }

        let target = MKMapPoint(coordinate)
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, routeCoordinate) in route.coordinates.enumerated() {
            let distance = MKMapPoint(routeCoordinate).distance(to: target)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return (route.coordinates[bestIndex], Int(route.cumulativeMeters[bestIndex].rounded()))
    }

    func submitCourse() async -> Course? {
        guard let route = routeState.plannedRoute, canSubmit else { return nil }

        isSubmitting = true
        submissionErrorMessage = nil
        defer { isSubmitting = false }

        let routePoints = downsampled(route.coordinates).enumerated().map { index, coordinate in
            CourseCreatePayload.RoutePointPayload(
                sequence: index,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
        let payload = CourseCreatePayload(
            name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: courseSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            difficulty: difficulty,
            distanceMeters: route.distanceMeters,
            estimatedDurationSeconds: route.durationSeconds,
            routeSource: .plannedMapKit,
            routePoints: routePoints,
            elements: elementDrafts.map { draft in
                CourseCreatePayload.ElementPayload(
                    category: draft.category,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    distanceFromStartMeters: draft.distanceFromStartMeters,
                    title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        )

        do {
            return try await apiClient.createCourse(payload)
        } catch {
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription {
                submissionErrorMessage = description
            } else {
                submissionErrorMessage = "코스를 등록하지 못했어요. 잠시 후 다시 시도해 주세요."
            }
            return nil
        }
    }

    private func recalculateRoute() {
        routeTask?.cancel()
        elementDrafts.removeAll()

        guard waypoints.count >= 2 else {
            routeState = .idle
            return
        }

        routeState = .calculating
        let waypointSnapshot = waypoints
        routeTask = Task { [weak self] in
            do {
                let route = try await Self.calculateWalkingRoute(through: waypointSnapshot)
                guard !Task.isCancelled else { return }
                self?.routeState = .ready(route)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.routeState = .failed(message: "보행 경로를 계산하지 못했어요. 지점을 조정하거나 다시 시도해 주세요.")
            }
        }
    }

    private static func calculateWalkingRoute(through waypoints: [CLLocationCoordinate2D]) async throws -> PlannedRoute {
        var combinedCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance = 0.0
        var totalDuration = 0.0

        for (start, finish) in zip(waypoints, waypoints.dropFirst()) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: finish))
            request.transportType = .walking

            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                throw MKError(.directionsNotFound)
            }

            let segmentCoordinates = route.polyline.coordinates
            if combinedCoordinates.isEmpty {
                combinedCoordinates.append(contentsOf: segmentCoordinates)
            } else {
                combinedCoordinates.append(contentsOf: segmentCoordinates.dropFirst())
            }
            totalDistance += route.distance
            totalDuration += route.expectedTravelTime
        }

        var cumulativeMeters: [Double] = []
        cumulativeMeters.reserveCapacity(combinedCoordinates.count)
        var runningDistance = 0.0
        for (index, coordinate) in combinedCoordinates.enumerated() {
            if index > 0 {
                runningDistance += MKMapPoint(combinedCoordinates[index - 1]).distance(to: MKMapPoint(coordinate))
            }
            cumulativeMeters.append(runningDistance)
        }

        return PlannedRoute(
            coordinates: combinedCoordinates,
            cumulativeMeters: cumulativeMeters,
            distanceMeters: max(1, Int(totalDistance.rounded())),
            durationSeconds: max(60, Int(totalDuration.rounded()))
        )
    }

    private func downsampled(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        let maximumPoints = 2_000
        guard coordinates.count > maximumPoints else { return coordinates }

        let stride = Double(coordinates.count - 1) / Double(maximumPoints - 1)
        return (0..<maximumPoints).map { index in
            coordinates[Int((Double(index) * stride).rounded())]
        }
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var result = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&result, range: NSRange(location: 0, length: pointCount))
        return result
    }
}
