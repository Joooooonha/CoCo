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

enum RouteOrigin {
    case mapKitPlanning
    case importedGPX
}

@MainActor
@Observable
final class RoutePlannerStore {
    static let maximumWaypoints = 7
    /// Average walking pace used when an imported GPX has no duration metadata.
    private static let fallbackWalkingSpeedMetersPerSecond = 1.25

    private(set) var waypoints: [CLLocationCoordinate2D] = []
    private(set) var routeState: RoutePlanState = .idle
    private(set) var routeOrigin: RouteOrigin = .mapKitPlanning
    var elementDrafts: [ElementDraft] = []
    var courseName = ""
    var courseSummary = ""
    var difficulty: CourseDifficulty = .moderate
    private(set) var isSubmitting = false
    private(set) var submissionErrorMessage: String?
    @ObservationIgnored private var routeTask: Task<Void, Never>?
    @ObservationIgnored private let apiClient: CourseAPIClient
    @ObservationIgnored private let calculator: any WalkingRouteCalculator

    /// One entry per leg between adjacent waypoints; `nil` means not resolved yet.
    /// Keeping resolved legs means adding a waypoint only costs one request
    /// instead of recomputing the whole route.
    @ObservationIgnored private var segments: [RouteSegment?] = []

    init(
        apiClient: CourseAPIClient = CourseAPIClient(),
        calculator: any WalkingRouteCalculator = MapKitWalkingRouteCalculator()
    ) {
        self.apiClient = apiClient
        self.calculator = calculator
    }

    var canAddWaypoint: Bool {
        routeOrigin == .mapKitPlanning && waypoints.count < Self.maximumWaypoints
    }

    var canContinueToDetails: Bool {
        guard routeState.plannedRoute != nil else { return false }
        return routeOrigin == .importedGPX || waypoints.count >= 2
    }

    var hasPlanningContent: Bool {
        !waypoints.isEmpty || routeState.plannedRoute != nil
    }

    var isClosedLoop: Bool {
        guard let first = waypoints.first, let last = waypoints.last, waypoints.count >= 2 else { return false }
        return abs(first.latitude - last.latitude) < 0.000_01
            && abs(first.longitude - last.longitude) < 0.000_01
    }

    var nextTapDescription: String {
        if routeOrigin == .importedGPX {
            return "가져온 GPX 경로를 확인하세요"
        }
        switch waypoints.count {
        case 0: return "지도를 탭해 출발지를 선택하세요"
        case Self.maximumWaypoints...: return "지점은 최대 \(Self.maximumWaypoints)개까지 선택할 수 있어요"
        default: return "지도를 탭해 경유지나 도착지를 추가하세요"
        }
    }

    func loadImportedRoute(_ gpxRoute: GPXRoute) {
        routeTask?.cancel()
        waypoints.removeAll()
        segments.removeAll()
        elementDrafts.removeAll()

        var cumulativeMeters: [Double] = []
        cumulativeMeters.reserveCapacity(gpxRoute.coordinates.count)
        var runningDistance = 0.0
        for (index, coordinate) in gpxRoute.coordinates.enumerated() {
            if index > 0 {
                runningDistance += MKMapPoint(gpxRoute.coordinates[index - 1])
                    .distance(to: MKMapPoint(coordinate))
            }
            cumulativeMeters.append(runningDistance)
        }

        let distanceMeters = gpxRoute.distanceMeters ?? max(1, Int(runningDistance.rounded()))
        let durationSeconds = gpxRoute.durationSeconds ?? max(
            60,
            Int((Double(distanceMeters) / Self.fallbackWalkingSpeedMetersPerSecond).rounded())
        )

        routeOrigin = .importedGPX
        routeState = .ready(PlannedRoute(
            coordinates: gpxRoute.coordinates,
            cumulativeMeters: cumulativeMeters,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds
        ))
    }

    func addWaypoint(_ coordinate: CLLocationCoordinate2D) {
        guard canAddWaypoint else { return }
        waypoints.append(coordinate)
        waypointsDidChange()
    }

    func closeLoopToStart() {
        guard let start = waypoints.first, waypoints.count >= 2, !isClosedLoop, canAddWaypoint else { return }
        waypoints.append(start)
        waypointsDidChange()
    }

    func removeLastWaypoint() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        waypointsDidChange()
    }

    func clearRoute() {
        routeTask?.cancel()
        waypoints.removeAll()
        segments.removeAll()
        elementDrafts.removeAll()
        routeState = .idle
        routeOrigin = .mapKitPlanning
    }

    func resetAll() {
        clearRoute()
        courseName = ""
        courseSummary = ""
        difficulty = .moderate
        submissionErrorMessage = nil
    }

    /// Resumes from the first unresolved leg; already resolved legs are kept.
    func retryRouteCalculation() {
        startProcessingSegments()
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
            routeSource: routeOrigin == .importedGPX ? .importedGPX : .plannedMapKit,
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

    /// Aligns the leg cache with the waypoint list and resumes calculation.
    /// Removing a waypoint drops its leg without issuing any request.
    private func waypointsDidChange() {
        elementDrafts.removeAll()
        resizeSegments()
        startProcessingSegments()
    }

    private func resizeSegments() {
        let requiredCount = max(0, waypoints.count - 1)
        if segments.count > requiredCount {
            segments.removeLast(segments.count - requiredCount)
        } else if segments.count < requiredCount {
            segments.append(contentsOf: Array(repeating: nil, count: requiredCount - segments.count))
        }
    }

    private func startProcessingSegments() {
        routeTask?.cancel()

        guard waypoints.count >= 2 else {
            routeState = .idle
            return
        }

        publishRouteState()
        routeTask = Task { [weak self] in
            await self?.processPendingSegments()
        }
    }

    /// Resolves legs that have no cached result, one at a time and in order.
    /// Already resolved legs are skipped, so a rapid series of taps still costs
    /// one request per new leg.
    private func processPendingSegments() async {
        while let index = segments.firstIndex(where: { $0 == nil }) {
            if Task.isCancelled { return }

            guard index + 1 < waypoints.count else { return }
            let origin = waypoints[index]
            let destination = waypoints[index + 1]

            do {
                let segment = try await calculator.calculateSegment(from: origin, to: destination)
                if Task.isCancelled { return }
                // The list can shrink while a request is in flight.
                guard index < segments.count else { return }
                segments[index] = segment
                publishRouteState()
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                routeState = .failed(
                    message: "보행 경로를 계산하지 못했어요. 지점을 조정하거나 다시 시도해 주세요."
                )
                return
            }
        }
    }

    private func publishRouteState() {
        guard waypoints.count >= 2 else {
            routeState = .idle
            return
        }

        let resolved = segments.compactMap { $0 }
        routeState = resolved.count == segments.count ? .ready(merge(resolved)) : .calculating
    }

    /// Joins resolved legs into one route. Purely local, so it is safe to redo
    /// whenever the cache changes.
    private func merge(_ resolvedSegments: [RouteSegment]) -> PlannedRoute {
        var combinedCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance = 0.0
        var totalDuration = 0.0

        for segment in resolvedSegments {
            if combinedCoordinates.isEmpty {
                combinedCoordinates.append(contentsOf: segment.coordinates)
            } else {
                // The first point repeats the previous leg's last point.
                combinedCoordinates.append(contentsOf: segment.coordinates.dropFirst())
            }
            totalDistance += segment.distanceMeters
            totalDuration += segment.durationSeconds
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

    /// Lets tests await the in-flight calculation instead of polling.
    func waitForRouteCalculation() async {
        await routeTask?.value
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
