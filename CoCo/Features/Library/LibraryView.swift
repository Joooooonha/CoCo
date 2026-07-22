import SwiftUI

struct LibraryView: View {
    @State private var store: LibraryStore

    init(store: LibraryStore = LibraryStore()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("보관함")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        segmentPicker
                    }
                }
        }
        .task {
            await store.load()
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
                LibraryCourseRow(course: course)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await store.load(force: true)
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

            Text("\(course.ownerName) · \(course.locationLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

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
