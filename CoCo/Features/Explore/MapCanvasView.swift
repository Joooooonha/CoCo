import MapKit
import SwiftUI

struct MapCanvasView: View {
    @Bindable var store: CourseStore
    var bottomInset: CGFloat = 190
    @State private var position: MapCameraPosition = .region(.seoulOverview)

    var body: some View {
        Map(position: $position) {
            if let course = store.selectedCourse {
                MapPolyline(coordinates: course.mapCoordinates)
                    .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

                if let start = course.mapCoordinates.first {
                    if course.isClosedLoop {
                        Annotation("출발 및 도착", coordinate: start) {
                            EndpointMarker(
                                title: "출발 및 도착",
                                symbolName: "arrow.triangle.2.circlepath",
                                color: .green
                            )
                        }
                    } else {
                        Annotation("출발", coordinate: start) {
                            EndpointMarker(title: "출발", symbolName: "figure.run", color: .green)
                        }
                    }
                }

                if !course.isClosedLoop, let finish = course.mapCoordinates.last {
                    Annotation("도착", coordinate: finish) {
                        EndpointMarker(title: "도착", symbolName: "flag.checkered", color: .red)
                    }
                }

                ForEach(course.elements) { element in
                    Annotation("", coordinate: element.mapCoordinate) {
                        Button {
                            store.showDetails(for: element)
                        } label: {
                            Image(systemName: element.category.symbolName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(element.category.tint, in: Circle())
                                .overlay {
                                    Circle().stroke(.white, lineWidth: 3)
                                }
                                .shadow(radius: 3, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(element.category.displayName), \(element.title)")
                        .accessibilityHint("요소 상세 정보를 엽니다")
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .padding(.bottom, bottomInset + 20)
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottomLeading) {
            if store.selectedCourse != nil, store.selectedElement == nil {
                ElementLegend()
                    .padding(.leading, 12)
                    .padding(.bottom, bottomInset + 12)
            }
        }
        .overlay {
            if let element = store.selectedElement {
                ElementDetailOverlay(element: element) {
                    store.dismissElementDetails()
                }
            }
        }
        .onChange(of: store.selectedCourseID) {
            updatePosition()
        }
        .onAppear {
            updatePosition()
        }
    }

    private func updatePosition() {
        guard let course = store.selectedCourse else {
            position = .region(.seoulOverview)
            return
        }
        position = .region(course.mapRegion)
    }
}

private struct EndpointMarker: View {
    let title: String
    let symbolName: String
    let color: Color

    var body: some View {
        Image(systemName: symbolName)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color, in: Circle())
            .overlay {
                Circle().stroke(.white, lineWidth: 3)
            }
            .accessibilityLabel(title)
    }
}

private struct ElementLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(ElementCategory.allCases, id: \.self) { category in
                Label(category.displayName, systemImage: category.symbolName)
                    .labelStyle(CompactLegendLabelStyle(color: category.tint))
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("지도 요소 범례: 경관, 주의, 편의")
    }
}

private struct CompactLegendLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 2) {
            configuration.icon
                .foregroundStyle(color)
            configuration.title
                .font(.caption2)
                .foregroundStyle(.primary)
        }
    }
}

private struct ElementDetailOverlay: View {
    let element: CourseElement
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label(element.category.displayName, systemImage: element.category.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(element.category.tint)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("요소 상세 닫기")
                }

                Text(distanceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(element.title)
                    .font(.title3.weight(.bold))

                Text(element.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: 340, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 180)
            .shadow(radius: 14, y: 6)
        }
    }

    private var distanceLabel: String {
        if element.distanceFromStartMeters >= 1_000 {
            return String(format: "출발점에서 %.1f km", Double(element.distanceFromStartMeters) / 1_000)
        }
        return "출발점에서 \(element.distanceFromStartMeters) m"
    }
}

private extension Course {
    var mapCoordinates: [CLLocationCoordinate2D] {
        routePoints
            .sorted { $0.sequence < $1.sequence }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var mapRegion: MKCoordinateRegion {
        let coordinates = mapCoordinates
        guard let first = coordinates.first else { return .seoulOverview }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minimumLatitude = latitudes.min() ?? first.latitude
        let maximumLatitude = latitudes.max() ?? first.latitude
        let minimumLongitude = longitudes.min() ?? first.longitude
        let maximumLongitude = longitudes.max() ?? first.longitude

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minimumLatitude + maximumLatitude) / 2,
                longitude: (minimumLongitude + maximumLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maximumLatitude - minimumLatitude) * 1.35, 0.008),
                longitudeDelta: max((maximumLongitude - minimumLongitude) * 1.35, 0.008)
            )
        )
    }

    var isClosedLoop: Bool {
        guard let first = mapCoordinates.first, let last = mapCoordinates.last else { return false }
        return abs(first.latitude - last.latitude) < 0.000_01
            && abs(first.longitude - last.longitude) < 0.000_01
    }
}

private extension CourseElement {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension MKCoordinateRegion {
    static let seoulOverview = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.537, longitude: 126.976),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.18)
    )
}
