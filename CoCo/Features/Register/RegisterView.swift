import MapKit
import SwiftUI

struct RegisterView: View {
    let onRegistered: (Course) -> Void

    @State private var planner = RoutePlannerStore()
    @State private var showsDetails = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.537, longitude: 126.976),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.18)
        )
    )

    var body: some View {
        NavigationStack {
            plannerMap
                .navigationTitle("코스 등록")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    plannerControls
                }
                .navigationDestination(isPresented: $showsDetails) {
                    CourseSubmissionView(planner: planner) { course in
                        showsDetails = false
                        onRegistered(course)
                    }
                }
        }
        .onChange(of: planner.routeState) { _, newState in
            guard let route = newState.plannedRoute else { return }
            withAnimation {
                position = .region(fittedRegion(for: route.coordinates))
            }
        }
    }

    private func fittedRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2,
            longitude: ((longitudes.min() ?? 0) + (longitudes.max() ?? 0)) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(((latitudes.max() ?? 0) - (latitudes.min() ?? 0)) * 1.5, 0.008),
            longitudeDelta: max(((longitudes.max() ?? 0) - (longitudes.min() ?? 0)) * 1.5, 0.008)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private var plannerMap: some View {
        MapReader { proxy in
            Map(position: $position) {
                if let route = planner.routeState.plannedRoute {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(planner.waypoints.enumerated()), id: \.offset) { index, coordinate in
                    Annotation(waypointTitle(at: index), coordinate: coordinate) {
                        WaypointMarker(
                            label: waypointMarkerLabel(at: index),
                            color: waypointColor(at: index)
                        )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { screenPoint in
                guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
                planner.addWaypoint(coordinate)
            }
        }
    }

    private var plannerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(planner.nextTapDescription)
                .font(.subheadline.weight(.semibold))

            switch planner.routeState {
            case .idle:
                if planner.waypoints.count == 1 {
                    Text("한 지점을 더 선택하면 보행 경로를 계산해요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .calculating:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("보행 경로를 계산하는 중")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            case .ready(let route):
                Text(String(
                    format: "%.1f km · 약 %d분 · 지점 %d개",
                    Double(route.distanceMeters) / 1_000,
                    Int(ceil(Double(route.durationSeconds) / 60)),
                    planner.waypoints.count
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            case .failed(let message):
                HStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button("다시 계산") {
                        planner.retryRouteCalculation()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 8) {
                Button {
                    planner.removeLastWaypoint()
                } label: {
                    Label("되돌리기", systemImage: "arrow.uturn.backward")
                        .frame(minHeight: 28)
                }
                .buttonStyle(.bordered)
                .disabled(planner.waypoints.isEmpty)

                Button {
                    planner.closeLoopToStart()
                } label: {
                    Label("순환 코스", systemImage: "arrow.triangle.2.circlepath")
                        .frame(minHeight: 28)
                }
                .buttonStyle(.bordered)
                .disabled(planner.waypoints.count < 2 || planner.isClosedLoop || !planner.canAddWaypoint)

                Button(role: .destructive) {
                    planner.clearRoute()
                } label: {
                    Label("지우기", systemImage: "trash")
                        .frame(minHeight: 28)
                }
                .buttonStyle(.bordered)
                .disabled(planner.waypoints.isEmpty)
            }
            .font(.subheadline)

            Button {
                showsDetails = true
            } label: {
                Text("다음")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!planner.canContinueToDetails)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private func waypointTitle(at index: Int) -> String {
        if index == 0 {
            return "출발"
        }
        if index == planner.waypoints.count - 1, planner.waypoints.count >= 2 {
            return planner.isClosedLoop ? "도착(순환)" : "도착"
        }
        return "경유 \(index)"
    }

    private func waypointMarkerLabel(at index: Int) -> String {
        if index == 0 {
            return "출"
        }
        if index == planner.waypoints.count - 1, planner.waypoints.count >= 2 {
            return "도"
        }
        return "\(index)"
    }

    private func waypointColor(at index: Int) -> Color {
        if index == 0 {
            return .green
        }
        if index == planner.waypoints.count - 1, planner.waypoints.count >= 2 {
            return .red
        }
        return .blue
    }
}

private struct WaypointMarker: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .overlay {
                Circle().stroke(.white, lineWidth: 3)
            }
            .shadow(radius: 2, y: 1)
    }
}

#Preview {
    RegisterView { _ in }
}
