import CoreLocation
import MapKit

/// One leg of a planned route: the real walking path between two adjacent waypoints.
struct RouteSegment: Equatable, Sendable {
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
    let durationSeconds: Double

    static func == (lhs: RouteSegment, rhs: RouteSegment) -> Bool {
        lhs.distanceMeters == rhs.distanceMeters
            && lhs.durationSeconds == rhs.durationSeconds
            && lhs.coordinates.count == rhs.coordinates.count
    }
}

/// Resolves the walking path between two points.
///
/// `MKDirections.Request` only accepts a source and a destination, so a route
/// with waypoints has to be requested one leg at a time. Keeping this behind a
/// protocol lets the planner cache legs and lets tests count how many requests
/// a given interaction actually makes.
protocol WalkingRouteCalculator: Sendable {
    func calculateSegment(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RouteSegment
}

struct MapKitWalkingRouteCalculator: WalkingRouteCalculator {
    func calculateSegment(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RouteSegment {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw MKError(.directionsNotFound)
        }

        return RouteSegment(
            coordinates: route.polyline.coordinates,
            distanceMeters: route.distance,
            durationSeconds: route.expectedTravelTime
        )
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var result = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&result, range: NSRange(location: 0, length: pointCount))
        return result
    }
}
