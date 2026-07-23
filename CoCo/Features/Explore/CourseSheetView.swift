import SwiftUI

struct CourseSheetView: View {
    @Bindable var store: CourseStore
    @Binding var height: CGFloat
    let currentHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var dragBaseHeight: CGFloat?
    @State private var editingElementDraft: ElementDraft?
    @State private var elementPendingDeletion: CourseElement?

    private var isExpanded: Bool {
        currentHeight > (minHeight + maxHeight) / 2
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                grabber

                if let element = store.selectedElement {
                    elementDetailHeader(element)
                } else {
                    header
                }
            }
            .contentShape(Rectangle())
            .gesture(resizeGesture)

            Divider()

            if let element = store.selectedElement {
                elementDetailContent(element)
            } else {
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
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(item: $editingElementDraft) { draft in
            ElementDraftEditorView(draft: draft) { updatedDraft in
                Task {
                    guard let courseID = store.selectedCourseID else { return }
                    _ = await store.saveElement(updatedDraft, isNew: false, for: courseID)
                }
            } onDelete: { deletedDraft in
                if let element = store.selectedCourse?.elements.first(where: { $0.id == deletedDraft.id }) {
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
    }

    private func elementDetailHeader(_ element: CourseElement) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                store.dismissElementDetails()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("코스 목록으로 돌아가기")

            VStack(alignment: .leading, spacing: 3) {
                Label(element.category.displayName, systemImage: element.category.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(element.category.tint)

                Text(element.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func elementDetailContent(_ element: CourseElement) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(elementDistanceLabel(element))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(element.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if store.isSelectedCourseMine {
                    HStack(spacing: 8) {
                        Button {
                            editingElementDraft = ElementDraft(element: element)
                        } label: {
                            Label("수정", systemImage: "pencil")
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 28)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .accessibilityHint("요소 내용을 수정합니다")

                        Button(role: .destructive) {
                            elementPendingDeletion = element
                        } label: {
                            Label("삭제", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 28)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .accessibilityHint("요소를 삭제합니다")
                    }
                    .disabled(store.isSavingElement)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func elementDistanceLabel(_ element: CourseElement) -> String {
        if element.distanceFromStartMeters >= 1_000 {
            return String(format: "출발점에서 %.1f km", Double(element.distanceFromStartMeters) / 1_000)
        }
        return "출발점에서 \(element.distanceFromStartMeters) m"
    }

    /// Follows the finger continuously and stays wherever the drag ends,
    /// clamped between the minimum and maximum heights.
    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let baseHeight = dragBaseHeight ?? currentHeight
                dragBaseHeight = baseHeight
                height = min(max(baseHeight - value.translation.height, minHeight), maxHeight)
            }
            .onEnded { _ in
                dragBaseHeight = nil
            }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color(uiColor: .systemGray3))
            .frame(width: 36, height: 5)
            .padding(.top, 6)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
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
                withAnimation(.spring(duration: 0.32)) {
                    height = isExpanded ? minHeight : maxHeight
                }
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

    private var loadedContent: some View {
        // The list stays scrollable at every sheet height; selected courses
        // sort first so they remain visible in low sheet positions.
        List(orderedCourses) { course in
            CourseRow(
                store: store,
                course: course,
                isSelected: store.selectedCourseID == course.id,
                showsDetails: store.selectedCourseID == course.id,
                action: {
                    store.toggleSelection(course)
                },
                onAddElement: {
                    store.isAddingElement = true
                    withAnimation(.spring(duration: 0.32)) {
                        height = minHeight
                    }
                }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var orderedCourses: [Course] {
        guard let selectedCourseID = store.selectedCourseID else { return store.courses }
        return store.courses.sorted { first, second in
            (first.id == selectedCourseID ? 0 : 1, first.name)
                < (second.id == selectedCourseID ? 0 : 1, second.name)
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
    let store: CourseStore
    let course: Course
    let isSelected: Bool
    let showsDetails: Bool
    let action: () -> Void
    let onAddElement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if isSelected {
                CourseActionBar(store: store, course: course, onAddElement: onAddElement)
            }
        }
    }

    private var ownerInitial: String {
        String(course.ownerName.prefix(1))
    }

    private var accessibilityLabel: String {
        "\(course.name), \(course.difficulty.displayName), \(course.ownerName), \(course.locationLabel), \(String(format: "%.1f", course.distanceKilometers))킬로미터, 약 \(course.estimatedMinutes)분"
    }
}

private struct CourseActionBar: View {
    let store: CourseStore
    let course: Course
    let onAddElement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scrapButton

                    ForEach(ReactionType.allCases, id: \.self) { reaction in
                        reactionButton(reaction)
                    }

                    if store.isSelectedCourseMine {
                        addElementButton
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            if let actionErrorMessage = store.actionErrorMessage {
                Text(actionErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var addElementButton: some View {
        Button(action: onAddElement) {
            Label("요소 추가", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 28)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.green)
        .disabled(store.isAddingElement || store.isSavingElement)
        .accessibilityHint("지도를 탭해 내 코스에 요소를 추가합니다")
    }

    private var scrapButton: some View {
        Button {
            Task {
                await store.toggleScrap(for: course)
            }
        } label: {
            Label("\(course.scrapCount)", systemImage: course.isScrapped ? "bookmark.fill" : "bookmark")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 28)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(course.isScrapped ? .green : .secondary)
        .disabled(store.pendingScrapCourseIDs.contains(course.id))
        .accessibilityLabel("스크랩")
        .accessibilityValue("\(course.scrapCount)개")
        .accessibilityHint(course.isScrapped ? "탭하면 스크랩을 해제합니다" : "탭하면 보관함에 저장합니다")
        .accessibilityAddTraits(course.isScrapped ? .isSelected : [])
    }

    private func reactionButton(_ reaction: ReactionType) -> some View {
        let isOn = course.myReactions.contains(reaction)

        return Button {
            Task {
                await store.toggleReaction(reaction, for: course)
            }
        } label: {
            Label(
                "\(course.reactionCounts.count(for: reaction))",
                systemImage: isOn ? reaction.filledSymbolName : reaction.symbolName
            )
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 28)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(isOn ? .green : .secondary)
        .disabled(store.isReactionPending(reaction, for: course.id))
        .accessibilityLabel(reaction.displayName)
        .accessibilityValue("\(course.reactionCounts.count(for: reaction))개")
        .accessibilityHint(isOn ? "탭하면 반응을 해제합니다" : "탭하면 반응을 남깁니다")
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
