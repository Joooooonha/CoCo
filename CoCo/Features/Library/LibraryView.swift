import SwiftUI

struct LibraryView: View {
    var onOpenCourse: ((Course) -> Void)?
    var onSessionReset: (() -> Void)?
    @State private var store: LibraryStore
    @State private var accountStore = AccountStore()
    @State private var showsProfile = false
    @State private var coursePendingDeletion: Course?

    init(
        store: LibraryStore = LibraryStore(),
        onOpenCourse: ((Course) -> Void)? = nil,
        onSessionReset: (() -> Void)? = nil
    ) {
        _store = State(initialValue: store)
        self.onOpenCourse = onOpenCourse
        self.onSessionReset = onSessionReset
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("보관함")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        segmentPicker
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsProfile = true
                        } label: {
                            Label("내 계정", systemImage: "person.crop.circle")
                        }
                        .accessibilityHint("로그인과 이름, 계정 삭제를 관리합니다")
                    }
                }
                .sheet(isPresented: $showsProfile) {
                    ProfileView(
                        store: accountStore,
                        currentName: store.profileName,
                        onRename: { newName in
                            await store.updateDisplayName(newName)
                            await accountStore.load()
                        },
                        onSessionReset: {
                            // Logging in, out, or deleting swaps the identity, so the
                            // library has to be rebuilt for the new session.
                            Task {
                                await store.load(force: true)
                                onSessionReset?()
                            }
                        }
                    )
                }
                .alert(
                    "이름을 바꾸지 못했어요",
                    isPresented: Binding(
                        get: { store.profileErrorMessage != nil },
                        set: { if !$0 { store.clearProfileError() } }
                    )
                ) {
                    Button("확인", role: .cancel) {
                        store.clearProfileError()
                    }
                } message: {
                    Text(store.profileErrorMessage ?? "")
                }
        }
        .onAppear {
            // Refreshes silently on every tab entry so scrap and course
            // changes made in other tabs stay in sync.
            Task {
                await store.load(force: true)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("보관함을 불러오는 중")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
        case .failed(let message):
            ContentUnavailableView {
                Label("보관함을 불러올 수 없어요", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("다시 시도", systemImage: "arrow.clockwise") {
                    Task {
                        await store.load(force: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        case .empty, .loaded:
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if store.courses.isEmpty {
            emptyContent
                .background(Color(uiColor: .systemGroupedBackground))
        } else {
            List(store.courses) { course in
                Button {
                    onOpenCourse?(course)
                } label: {
                    LibraryCourseRow(course: course)
                }
                .buttonStyle(.plain)
                .accessibilityHint("탐색 지도에서 이 코스를 엽니다")
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .swipeActions(edge: .trailing) {
                    if store.segment == .myCourses {
                        Button(role: .destructive) {
                            coursePendingDeletion = course
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await store.load(force: true)
            }
            .confirmationDialog(
                "이 코스를 삭제할까요?",
                isPresented: Binding(
                    get: { coursePendingDeletion != nil },
                    set: { if !$0 { coursePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("코스 삭제", role: .destructive) {
                    guard let course = coursePendingDeletion else { return }
                    coursePendingDeletion = nil
                    Task {
                        await store.deleteMyCourse(course)
                    }
                }
                Button("취소", role: .cancel) {
                    coursePendingDeletion = nil
                }
            } message: {
                Text("경로와 요소, 다른 사용자의 스크랩·반응까지 함께 삭제되고 되돌릴 수 없어요.")
            }
            .alert(
                "코스를 삭제하지 못했어요",
                isPresented: Binding(
                    get: { store.deleteErrorMessage != nil },
                    set: { if !$0 { store.clearDeleteError() } }
                )
            ) {
                Button("확인", role: .cancel) {
                    store.clearDeleteError()
                }
            } message: {
                Text(store.deleteErrorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        switch store.segment {
        case .scraps:
            ContentUnavailableView {
                Label("스크랩한 코스가 없어요", systemImage: "bookmark")
            } description: {
                Text("탐색 탭에서 코스를 선택하고 스크랩하면 여기에서 다시 볼 수 있어요.")
            } actions: {
                refreshButton
            }
        case .myCourses:
            ContentUnavailableView {
                Label("내가 만든 코스가 없어요", systemImage: "figure.run.circle")
            } description: {
                Text("코스 등록 기능이 열리면 직접 계획한 코스가 여기에 표시돼요.")
            } actions: {
                refreshButton
            }
        }
    }

    private var refreshButton: some View {
        Button("새로 고침", systemImage: "arrow.clockwise") {
            Task {
                await store.load(force: true)
            }
        }
        .buttonStyle(.bordered)
    }

    private var segmentPicker: some View {
        Picker("보관함 구분", selection: $store.segment) {
            ForEach(LibrarySegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
    }
}

private struct LibraryCourseRow: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(course.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(course.difficulty.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if course.isScrapped {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
            }

            HStack(spacing: 6) {
                Text("\(course.ownerName) · \(course.locationLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            Text(String(format: "%.1f km · 약 %d분", course.distanceKilometers, course.estimatedMinutes))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label("\(course.scrapCount)", systemImage: "bookmark")
                ForEach(ReactionType.allCases, id: \.self) { reaction in
                    Label("\(course.reactionCounts.count(for: reaction))", systemImage: reaction.symbolName)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(reactionSummary)
        }
        .accessibilityElement(children: .combine)
    }

    private var reactionSummary: String {
        "스크랩 \(course.scrapCount)개, " + ReactionType.allCases
            .map { "\($0.displayName) \(course.reactionCounts.count(for: $0))개" }
            .joined(separator: ", ")
    }
}

#Preview {
    LibraryView(store: LibraryStore(scraps: SeedData.courses))
}
