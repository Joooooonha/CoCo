import MapKit
import SwiftUI

struct CourseSubmissionView: View {
    @Bindable var planner: RoutePlannerStore
    let onRegistered: (Course) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editingDraft: ElementDraft?

    var body: some View {
        Form {
            Section("코스 정보") {
                TextField("코스 이름", text: $planner.courseName)
                    .textInputAutocapitalization(.never)

                TextField("한 줄 설명", text: $planner.courseSummary, axis: .vertical)
                    .lineLimit(1...3)

                Picker("난이도", selection: $planner.difficulty) {
                    ForEach(CourseDifficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.displayName).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                elementMap

                if planner.elementDrafts.isEmpty {
                    Text("경로 지도를 탭해 경관·주의·편의 요소를 1개 이상 추가해 주세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(planner.elementDrafts) { draft in
                        Button {
                            editingDraft = draft
                        } label: {
                            ElementDraftRow(draft: draft)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        planner.elementDrafts.remove(atOffsets: offsets)
                    }
                }
            } header: {
                Text("코스 요소")
            } footer: {
                Text("요소는 경로 위 가장 가까운 지점에 붙습니다. 등록에는 요소가 1개 이상 필요해요.")
            }

        }
        .navigationTitle("코스 정보 입력")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            submitBar
        }
        .sheet(item: $editingDraft) { draft in
            ElementDraftEditorView(draft: draft) { updatedDraft in
                if let index = planner.elementDrafts.firstIndex(where: { $0.id == updatedDraft.id }) {
                    planner.elementDrafts[index] = updatedDraft
                } else {
                    planner.elementDrafts.append(updatedDraft)
                }
            } onDelete: { deletedDraft in
                planner.elementDrafts.removeAll { $0.id == deletedDraft.id }
            }
        }
    }

    private var submitBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let submissionErrorMessage = planner.submissionErrorMessage {
                Text(submissionErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if !planner.canSubmit, !planner.isSubmitting, !validationHint.isEmpty {
                Text(validationHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    if let course = await planner.submitCourse() {
                        let registeredCourse = course
                        planner.resetAll()
                        dismiss()
                        onRegistered(registeredCourse)
                    }
                }
            } label: {
                if planner.isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("등록하는 중")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("코스 등록")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!planner.canSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private var elementMap: some View {
        MapReader { proxy in
            Map(initialPosition: routeCameraPosition) {
                if let route = planner.routeState.plannedRoute {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }

                ForEach(planner.elementDrafts) { draft in
                    Annotation(draft.title, coordinate: CLLocationCoordinate2D(latitude: draft.latitude, longitude: draft.longitude)) {
                        Image(systemName: draft.category.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(draft.category.tint, in: Circle())
                            .overlay {
                                Circle().stroke(.white, lineWidth: 2)
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .frame(height: 240)
            .listRowInsets(EdgeInsets())
            .onTapGesture { screenPoint in
                guard let tapped = proxy.convert(screenPoint, from: .local),
                      let snapped = planner.nearestRoutePoint(to: tapped) else { return }
                editingDraft = ElementDraft(
                    id: UUID(),
                    category: .view,
                    latitude: snapped.coordinate.latitude,
                    longitude: snapped.coordinate.longitude,
                    distanceFromStartMeters: snapped.distanceFromStartMeters,
                    title: "",
                    description: ""
                )
            }
            .accessibilityLabel("경로 지도")
            .accessibilityHint("지도를 탭하면 경로 위에 코스 요소를 추가합니다")
        }
    }

    private var routeCameraPosition: MapCameraPosition {
        guard let route = planner.routeState.plannedRoute, !route.coordinates.isEmpty else {
            return .automatic
        }

        let latitudes = route.coordinates.map(\.latitude)
        let longitudes = route.coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2,
            longitude: ((longitudes.min() ?? 0) + (longitudes.max() ?? 0)) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(((latitudes.max() ?? 0) - (latitudes.min() ?? 0)) * 1.4, 0.008),
            longitudeDelta: max(((longitudes.max() ?? 0) - (longitudes.min() ?? 0)) * 1.4, 0.008)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    private var validationHint: String {
        var missing: [String] = []
        if planner.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("코스 이름")
        }
        if planner.courseSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("한 줄 설명")
        }
        if planner.elementDrafts.isEmpty {
            missing.append("코스 요소 1개 이상")
        }
        if missing.isEmpty {
            return ""
        }
        return "등록하려면 \(missing.joined(separator: ", "))이(가) 필요해요."
    }
}

private struct ElementDraftRow: View {
    let draft: ElementDraft

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: draft.category.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(draft.category.tint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title.isEmpty ? "제목 없는 요소" : draft.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text("\(draft.category.displayName) · 출발점에서 \(distanceLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("탭하면 요소를 수정합니다")
    }

    private var distanceLabel: String {
        if draft.distanceFromStartMeters >= 1_000 {
            return String(format: "%.1f km", Double(draft.distanceFromStartMeters) / 1_000)
        }
        return "\(draft.distanceFromStartMeters) m"
    }
}

