import MapKit
import SwiftUI

struct MapCanvasView: View {
    @Bindable var store: CourseStore
    var bottomInset: CGFloat = 190
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var position: MapCameraPosition = .region(.seoulOverview)
    @State private var editingElement: EditingElementDraft?
    @State private var elementPendingDeletion: CourseElement?

    var body: some View {
        MapReader { proxy in
            mapContent
                .onTapGesture { screenPoint in
                    guard store.isAddingElement,
                          store.isSelectedCourseMine,
                          let course = store.selectedCourse,
                          let tapped = proxy.convert(screenPoint, from: .local),
                          let snapped = course.nearestRoutePoint(to: tapped) else { return }
                    editingElement = EditingElementDraft(
                        draft: ElementDraft(
                            id: UUID(),
                            category: .view,
                            latitude: snapped.coordinate.latitude,
                            longitude: snapped.coordinate.longitude,
                            distanceFromStartMeters: snapped.distanceFromStartMeters,
                            title: "",
                            description: ""
                        ),
                        isNew: true
                    )
                }
        }
    }

    private var mapContent: some View {
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
            // The legend is redundant with the pins' VoiceOver labels and would
            // cover most of the map at accessibility text sizes.
            if store.selectedCourse != nil, store.selectedElement == nil, !store.isAddingElement,
               !dynamicTypeSize.isAccessibilitySize {
                ElementLegend()
                    .padding(.leading, 12)
                    .padding(.bottom, bottomInset + 12)
            }
        }
        .overlay(alignment: .top) {
            if store.isAddingElement {
                addElementBanner
            }
        }
        .overlay {
            if let element = store.selectedElement {
                ElementDetailOverlay(
                    element: element,
                    canManage: store.isSelectedCourseMine,
                    isBusy: store.isSavingElement,
                    onEdit: {
                        editingElement = EditingElementDraft(draft: ElementDraft(element: element), isNew: false)
                    },
                    onDelete: {
                        elementPendingDeletion = element
                    },
                    onDismiss: {
                        store.dismissElementDetails()
                    }
                )
            }
        }
        .sheet(item: $editingElement) { editing in
            ElementDraftEditorView(draft: editing.draft) { draft in
                Task {
                    _ = await store.saveElement(draft, isNew: editing.isNew, for: store.selectedCourseID ?? draft.id)
                }
            } onDelete: { draft in
                if let element = store.selectedCourse?.elements.first(where: { $0.id == draft.id }) {
                    elementPendingDeletion = element
                }
            }
        }
        .confirmationDialog(
            "이 요소를 삭제할까요?",
            isPresented: Binding(
                get: { elementPendingDeletion != nil },
                set: { if !$0 { elementPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("요소 삭제", role: .destructive) {
                guard let element = elementPendingDeletion else { return }
                elementPendingDeletion = nil
                Task {
                    await store.deleteElement(element)
                }
            }
            Button("취소", role: .cancel) {
                elementPendingDeletion = nil
            }
        } message: {
            Text("삭제한 요소는 되돌릴 수 없어요.")
        }
        .onChange(of: store.selectedCourseID) {
            updatePosition()
        }
        .onAppear {
            updatePosition()
        }
    }

    private var addElementBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("경로 근처를 탭해 요소 위치를 선택하세요")
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 8)

            Button("취소") {
                store.isAddingElement = false
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(radius: 6, y: 2)
        .accessibilityElement(children: .contain)
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

private struct EditingElementDraft: Identifiable {
    let draft: ElementDraft
    let isNew: Bool

    var id: UUID { draft.id }
}

private struct ElementDetailOverlay: View {
    let element: CourseElement
    let canManage: Bool
    let isBusy: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
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

                // Scroll only when large text makes the details exceed the card cap.
                ViewThatFits(in: .vertical) {
                    detailContent

                    ScrollView {
                        detailContent
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 340, alignment: .leading)
            .frame(maxHeight: 460)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 180)
            .shadow(radius: 14, y: 6)
        }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(distanceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(element.title)
                .font(.title3.weight(.bold))

            Text(element.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if canManage {
                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Label("수정", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityHint("요소 내용을 수정합니다")

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("삭제", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityHint("요소를 삭제합니다")
                }
                .disabled(isBusy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Snaps a tapped coordinate to the nearest route vertex and returns
    /// its cumulative distance from the course start.
    func nearestRoutePoint(
        to coordinate: CLLocationCoordinate2D
    ) -> (coordinate: CLLocationCoordinate2D, distanceFromStartMeters: Int)? {
        let coordinates = mapCoordinates
        guard !coordinates.isEmpty else { return nil }

        let target = MKMapPoint(coordinate)
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        var cumulativeMeters: [Double] = []
        cumulativeMeters.reserveCapacity(coordinates.count)
        var runningDistance = 0.0

        for (index, routeCoordinate) in coordinates.enumerated() {
            if index > 0 {
                runningDistance += MKMapPoint(coordinates[index - 1]).distance(to: MKMapPoint(routeCoordinate))
            }
            cumulativeMeters.append(runningDistance)

            let distance = MKMapPoint(routeCoordinate).distance(to: target)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return (coordinates[bestIndex], Int(cumulativeMeters[bestIndex].rounded()))
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
