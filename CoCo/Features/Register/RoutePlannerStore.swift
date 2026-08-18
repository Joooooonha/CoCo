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
    /// The photo already on the server, shown while editing.
    var savedPhoto: SavedPhoto?
    /// A newly picked photo, uploaded once the element itself is saved. A photo
    /// needs a server-side element to attach to, so it cannot go up any earlier.
    var pendingPhoto: ElementPhotoProcessor.Output?
    var removesSavedPhoto = false

    struct SavedPhoto: Equatable {
        let url: URL
        let uploadedAt: String
    }

    var hasVisiblePhoto: Bool {
        pendingPhoto != nil || (savedPhoto != nil && !removesSavedPhoto)
    }
}

enum RouteOrigin {
    case mapKitPlanning
    case importedGPX
    case drawnFreehand

    var routeSource: RouteSource {
        switch self {
        case .mapKitPlanning: .plannedMapKit
        case .importedGPX: .importedGPX
        case .drawnFreehand: .drawnFreehand
        }
    }
}

/// How the user is building the route right now.
enum RoutePlanMode: Equatable {
    /// Tap points and let MapKit resolve the walking path between them.
    case waypoints
    /// Draw the line directly, with no snapping to roads.
    case freehand
}

/// Resolution state of a single leg between two adjacent waypoints.
enum RouteSegmentState: Equatable {
    case pending
    case resolved(RouteSegment)
    case failed

    var segment: RouteSegment? {
        if case .resolved(let segment) = self {
            return segment
        }
        return nil
    }
}

@MainActor
@Observable
final class RoutePlannerStore {
    /// Start, up to 23 stops, and finish. Raising this further needs a real
    /// throttling measurement first; see `SPEC.md` V2 정밀 경로 계획.
    static let maximumWaypoints = 25
    /// Average walking pace used when an imported GPX has no duration metadata.
    private static let fallbackWalkingSpeedMetersPerSecond = 1.25

    private(set) var waypoints: [CLLocationCoordinate2D] = []
    private(set) var routeState: RoutePlanState = .idle
    private(set) var routeOrigin: RouteOrigin = .mapKitPlanning
    private(set) var mode: RoutePlanMode = .waypoints

    /// Each stroke is one uninterrupted drag. Lifting the finger to pan the map
    /// and drawing again appends another stroke to the same route.
    private(set) var drawnStrokes: [[CLLocationCoordinate2D]] = []
    var elementDrafts: [ElementDraft] = []
    var courseName = ""
    var courseSummary = ""
    var difficulty: CourseDifficulty = .moderate
    private(set) var isSubmitting = false
    private(set) var submissionErrorMessage: String?
    /// Set when the course itself registered but a photo did not. The course is
    /// usable, so this is shown after registration rather than blocking it.
    private(set) var photoWarningMessage: String?
    @ObservationIgnored private var routeTask: Task<Void, Never>?
    @ObservationIgnored private let apiClient: CourseAPIClient
    @ObservationIgnored private let calculator: any WalkingRouteCalculator

    /// One entry per leg between adjacent waypoints. Keeping resolved legs means
    /// adding a waypoint only costs one request instead of recomputing the route,
    /// and a leg that fails does not discard the legs that already succeeded.
    private(set) var segments: [RouteSegmentState] = []

    /// Attempts per leg before it is marked failed, and the base backoff between them.
    private static let maximumSegmentAttempts = 3
    private static let retryBackoff: Duration = .milliseconds(600)
    /// Apple throttles bursts of direction requests, so that case waits longer.
    private static let throttledBackoff: Duration = .seconds(3)

    init(
        apiClient: CourseAPIClient = CourseAPIClient(),
        calculator: any WalkingRouteCalculator = MapKitWalkingRouteCalculator()
    ) {
        self.apiClient = apiClient
        self.calculator = calculator
    }

    var canAddWaypoint: Bool {
        mode == .waypoints && routeOrigin == .mapKitPlanning && waypoints.count < Self.maximumWaypoints
    }

    var canContinueToDetails: Bool {
        guard routeState.plannedRoute != nil else { return false }
        switch routeOrigin {
        case .importedGPX, .drawnFreehand: return true
        case .mapKitPlanning: return waypoints.count >= 2
        }
    }

    var hasPlanningContent: Bool {
        !waypoints.isEmpty || !drawnStrokes.isEmpty || routeState.plannedRoute != nil
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
        if mode == .freehand {
            return drawnStrokes.isEmpty
                ? "지도 위에 손가락으로 경로를 그리세요"
                : "이어서 그리거나 지점 찍기로 돌아갈 수 있어요"
        }
        switch waypoints.count {
        case 0:
            return "지도를 탭해 출발지를 선택하세요"
        case Self.maximumWaypoints...:
            return "지점은 최대 \(Self.maximumWaypoints)개까지 선택할 수 있어요"
        default:
            // Denser points are how a route is steered onto the path the user
            // wants, so the remaining budget is worth showing.
            let remaining = Self.maximumWaypoints - waypoints.count
            return "지도를 탭해 경유지나 도착지를 추가하세요 (\(remaining)개 더 가능)"
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

    /// Switching modes discards the other mode's work, so the caller confirms
    /// with the user first when `hasPlanningContent` is true.
    func setMode(_ newMode: RoutePlanMode) {
        guard newMode != mode else { return }
        clearRoute()
        mode = newMode
    }

    /// Adds one finished drag to the drawn route. No snapping happens: the line
    /// the user drew is the route, which is what makes trails and shortcuts that
    /// the road network does not know about expressible.
    func appendDrawnStroke(_ coordinates: [CLLocationCoordinate2D]) {
        guard mode == .freehand, coordinates.count >= 2 else { return }

        routeTask?.cancel()
        waypoints.removeAll()
        segments.removeAll()
        elementDrafts.removeAll()

        drawnStrokes.append(coordinates)
        routeOrigin = .drawnFreehand
        publishDrawnRoute()
    }

    func undoLastStroke() {
        guard mode == .freehand, !drawnStrokes.isEmpty else { return }
        drawnStrokes.removeLast()
        elementDrafts.removeAll()

        if drawnStrokes.isEmpty {
            routeOrigin = .mapKitPlanning
            routeState = .idle
        } else {
            publishDrawnRoute()
        }
    }

    private func publishDrawnRoute() {
        let coordinates = drawnStrokes.flatMap { $0 }
        guard coordinates.count >= 2 else {
            routeState = .idle
            return
        }
        routeState = .ready(measuredRoute(through: coordinates))
    }

    /// Distance comes from the drawn coordinates themselves and time from an
    /// average walking pace, since no routing service is involved.
    private func measuredRoute(through coordinates: [CLLocationCoordinate2D]) -> PlannedRoute {
        var cumulativeMeters: [Double] = []
        cumulativeMeters.reserveCapacity(coordinates.count)
        var runningDistance = 0.0

        for (index, coordinate) in coordinates.enumerated() {
            if index > 0 {
                runningDistance += MKMapPoint(coordinates[index - 1]).distance(to: MKMapPoint(coordinate))
            }
            cumulativeMeters.append(runningDistance)
        }

        let distanceMeters = max(1, Int(runningDistance.rounded()))
        return PlannedRoute(
            coordinates: coordinates,
            cumulativeMeters: cumulativeMeters,
            distanceMeters: distanceMeters,
            durationSeconds: max(
                60,
                Int((Double(distanceMeters) / Self.fallbackWalkingSpeedMetersPerSecond).rounded())
            )
        )
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
        drawnStrokes.removeAll()
        elementDrafts.removeAll()
        routeState = .idle
        routeOrigin = .mapKitPlanning
    }

    func resetAll() {
        clearRoute()
        mode = .waypoints
        courseName = ""
        courseSummary = ""
        difficulty = .moderate
        submissionErrorMessage = nil
        photoWarningMessage = nil
    }

    /// Puts failed legs back in the queue and resumes. Resolved legs are kept, so
    /// a retry only re-requests what is actually missing.
    func retryRouteCalculation() {
        for index in segments.indices where segments[index] == .failed {
            segments[index] = .pending
        }
        startProcessingSegments()
    }

    /// Stops the in-flight calculation and leaves the remaining legs pending so
    /// the user can retry or adjust the waypoints.
    func cancelRouteCalculation() {
        routeTask?.cancel()
        routeTask = nil
        publishRouteState()
    }

    var totalSegmentCount: Int {
        segments.count
    }

    var resolvedSegmentCount: Int {
        segments.count { $0.segment != nil }
    }

    /// Waypoint pairs whose walking path could not be resolved. The register map
    /// draws these so the user can see exactly which points to fix.
    var failedConnections: [(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D)] {
        segments.indices.compactMap { index in
            guard segments[index] == .failed, index + 1 < waypoints.count else { return nil }
            return (waypoints[index], waypoints[index + 1])
        }
    }

    /// Contiguous runs of resolved legs. Drawing each run separately keeps the
    /// map honest: no line is drawn across a leg that has no real path.
    var resolvedPolylines: [[CLLocationCoordinate2D]] {
        var polylines: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []

        for state in segments {
            guard let segment = state.segment else {
                if current.count >= 2 { polylines.append(current) }
                current = []
                continue
            }
            if current.isEmpty {
                current.append(contentsOf: segment.coordinates)
            } else {
                current.append(contentsOf: segment.coordinates.dropFirst())
            }
        }
        if current.count >= 2 { polylines.append(current) }
        return polylines
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
            routeSource: routeOrigin.routeSource,
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
            let course = try await apiClient.createCourse(payload)
            return await uploadDraftPhotos(for: course)
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

    /// Sends the photos picked while drafting, now that the server has created
    /// the elements they belong to.
    ///
    /// A course is registered in one call, so the elements only get their
    /// identifiers back in the response. Drafts are matched to them by position
    /// after both are ordered by distance, and each pair is checked before
    /// uploading so a mismatch skips the photo instead of attaching it to the
    /// wrong element.
    private func uploadDraftPhotos(for course: Course) async -> Course {
        let draftsWithPhotos = elementDrafts.contains { $0.pendingPhoto != nil }
        guard draftsWithPhotos else { return course }

        let orderedDrafts = elementDrafts.sorted { $0.distanceFromStartMeters < $1.distanceFromStartMeters }
        guard orderedDrafts.count == course.elements.count else {
            photoWarningMessage = Self.photoWarning
            return course
        }

        var updatedCourse = course
        var failed = false

        for (draft, element) in zip(orderedDrafts, course.elements) {
            guard let photo = draft.pendingPhoto else { continue }
            guard draft.distanceFromStartMeters == element.distanceFromStartMeters,
                  draft.title.trimmingCharacters(in: .whitespacesAndNewlines) == element.title else {
                failed = true
                continue
            }

            do {
                let saved = try await apiClient.uploadElementPhoto(
                    courseID: course.id,
                    elementID: element.id,
                    photo: photo
                )
                updatedCourse.upsertElement(saved)
            } catch {
                failed = true
            }
        }

        photoWarningMessage = failed ? Self.photoWarning : nil
        return updatedCourse
    }

    private static let photoWarning = "코스는 등록됐지만 일부 사진을 올리지 못했어요. 요소 수정에서 다시 추가해 주세요."

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
            segments.append(contentsOf: Array(repeating: .pending, count: requiredCount - segments.count))
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

    /// Resolves pending legs one at a time and in order. Already resolved legs
    /// are skipped, and a leg that keeps failing is marked so the remaining legs
    /// still get their chance instead of the whole route being discarded.
    private func processPendingSegments() async {
        while let index = segments.firstIndex(of: .pending) {
            if Task.isCancelled { return }

            guard index + 1 < waypoints.count else { return }
            let origin = waypoints[index]
            let destination = waypoints[index + 1]

            let resolved = await resolveSegment(from: origin, to: destination)
            if Task.isCancelled { return }
            // The list can shrink while a request is in flight.
            guard index < segments.count, segments[index] == .pending else { continue }

            segments[index] = resolved.map { RouteSegmentState.resolved($0) } ?? .failed
            publishRouteState()
        }
    }

    /// Retries a single leg with a growing delay before giving up on it.
    private func resolveSegment(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> RouteSegment? {
        for attempt in 0..<Self.maximumSegmentAttempts {
            if Task.isCancelled { return nil }

            do {
                return try await calculator.calculateSegment(from: origin, to: destination)
            } catch is CancellationError {
                return nil
            } catch {
                let isLastAttempt = attempt == Self.maximumSegmentAttempts - 1
                if isLastAttempt { return nil }

                let base = isThrottled(error) ? Self.throttledBackoff : Self.retryBackoff
                let backoff = base * Int(pow(2.0, Double(attempt)))
                do {
                    try await Task.sleep(for: backoff)
                } catch {
                    return nil
                }
            }
        }
        return nil
    }

    private func isThrottled(_ error: any Error) -> Bool {
        (error as? MKError)?.code == .loadingThrottled
    }

    private func publishRouteState() {
        guard waypoints.count >= 2 else {
            routeState = .idle
            return
        }

        if segments.contains(.pending) {
            routeState = .calculating
            return
        }

        let resolvedSegments = segments.compactMap(\.segment)
        if resolvedSegments.count == segments.count {
            routeState = .ready(merge(resolvedSegments))
            return
        }

        let failedCount = segments.count - resolvedSegments.count
        routeState = .failed(
            message: "구간 \(failedCount)개의 보행 경로를 찾지 못했어요. 해당 지점을 옮기거나 지운 뒤 다시 시도해 주세요."
        )
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
