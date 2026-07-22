import SwiftUI

struct CourseSheetView: View {
    @Bindable var store: CourseStore
    @Binding var selectedDetent: PresentationDetent

    private var isExpanded: Bool {
        selectedDetent == .large
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            switch store.loadState {
            case .idle, .loading:
                loadingContent
            case .failed(let message):
                stateContent(
                    title: "코스를 불러올 수 없어요",
                    description: message,
                    symbolName: "wifi.exclamationmark"
                )
            case .empty:
                stateContent(
                    title: "등록된 코스가 없어요",
                    description: "새 코스를 확인하려면 다시 불러와 주세요.",
                    symbolName: "figure.run.circle"
                )
            case .loaded:
                loadedContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("이 지도 영역에서")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(courseCountTitle)
                    .font(.title3.weight(.bold))

                if let selectedCourse = store.selectedCourse {
                    Label("\(selectedCourse.name) 경로를 표시 중", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                selectedDetent = isExpanded ? .height(190) : .large
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "코스 목록 접기" : "코스 목록 펼치기")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var courseCountTitle: String {
        switch store.loadState {
        case .loaded:
            "러닝 코스 \(store.courses.count)개"
        default:
            "러닝 코스"
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if isExpanded {
            List(store.courses) { course in
                CourseRow(
                    course: course,
                    isSelected: store.selectedCourseID == course.id,
                    showsDetails: store.selectedCourseID == course.id
                ) {
                    store.toggleSelection(course)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        } else if let selectedCourse = store.selectedCourse {
            CourseRow(course: selectedCourse, isSelected: true, showsDetails: false) {
                store.toggleSelection(selectedCourse)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else {
            ContentUnavailableView(
                "코스를 선택해 경로를 확인하세요",
                systemImage: "figure.run.circle",
                description: Text("목록을 펼치면 공유 코스 \(store.courses.count)개를 볼 수 있어요.")
            )
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var loadingContent: some View {
        if isExpanded {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)

                Text("공유 코스를 불러오는 중")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: 12) {
                ProgressView()

                Text("공유 코스를 불러오는 중")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func stateContent(
        title: String,
        description: String,
        symbolName: String
    ) -> some View {
        if isExpanded {
            ContentUnavailableView {
                Label(title, systemImage: symbolName)
            } description: {
                Text(description)
            } actions: {
                Button("다시 시도", systemImage: "arrow.clockwise") {
                    reloadCourses()
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Button {
                    reloadCourses()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("코스 다시 불러오기")
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
        }
    }

    private func reloadCourses() {
        Task {
            await store.loadCourses(force: true)
        }
    }
}

private struct CourseRow: View {
    let course: Course
    let isSelected: Bool
    let showsDetails: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(ownerInitial)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.green, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(course.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(course.difficulty.displayName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text("\(course.ownerName) · \(course.locationLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(String(format: "%.1f km · 약 %d분", course.distanceKilometers, course.estimatedMinutes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(isSelected ? Color.green : Color.secondary)
                        .accessibilityHidden(true)
                }

                if showsDetails {
                    Divider()

                    Text(course.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 16) {
                        ElementCount(category: .facility, count: course.elements.count { $0.category == .facility })
                        ElementCount(category: .caution, count: course.elements.count { $0.category == .caution })
                        ElementCount(category: .view, count: course.elements.count { $0.category == .view })
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "다시 탭하면 선택을 해제합니다" : "지도에 코스 경로를 표시합니다")
    }

    private var ownerInitial: String {
        String(course.ownerName.prefix(1))
    }

    private var accessibilityLabel: String {
        "\(course.name), \(course.difficulty.displayName), \(course.ownerName), \(course.locationLabel), \(String(format: "%.1f", course.distanceKilometers))킬로미터, 약 \(course.estimatedMinutes)분"
    }
}

private struct ElementCount: View {
    let category: ElementCategory
    let count: Int

    var body: some View {
        Label("\(category.displayName) \(count)", systemImage: category.symbolName)
            .font(.caption)
            .foregroundStyle(category.tint)
    }
}
