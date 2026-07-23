//
//  ContentView.swift
//  CoCo
//
//  Created by 박준하 on 7/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var store: CourseStore
    @State private var selectedTab: MainTab = .explore
    @State private var panelHeight: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(store: CourseStore = CourseStore()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("탐색", systemImage: "map.fill", value: MainTab.explore) {
                exploreTab
            }

            Tab("등록", systemImage: "plus.circle.fill", value: MainTab.register) {
                RegisterView { course in
                    selectedTab = .explore
                    Task {
                        await store.loadCourses(force: true)
                        store.selectedCourseID = course.id
                    }
                }
            }

            Tab("보관함", systemImage: "bookmark.fill", value: MainTab.library) {
                LibraryView()
            }
        }
        .task {
            await store.loadCourses()
        }
    }

    /// Scales the panel bounds with the text size so larger Dynamic Type
    /// content is not clipped by fixed heights.
    private var panelTypeScale: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large: 1.0
        case .xLarge: 1.08
        case .xxLarge: 1.16
        case .xxxLarge: 1.25
        case .accessibility1: 1.5
        case .accessibility2: 1.7
        case .accessibility3: 1.9
        case .accessibility4: 2.05
        default: 2.2
        }
    }

    private func panelMinHeight(fullHeight: CGFloat) -> CGFloat {
        min(132 * panelTypeScale, fullHeight * 0.45)
    }

    /// The height that reveals the selected course row and its action bar.
    private func panelPeekHeight(fullHeight: CGFloat) -> CGFloat {
        min(340 * panelTypeScale, fullHeight * 0.6)
    }

    private var exploreTab: some View {
        NavigationStack {
            GeometryReader { proxy in
                let fullHeight = proxy.size.height
                let minHeight = panelMinHeight(fullHeight: fullHeight)
                let height = panelHeight == 0
                    ? min(190 * panelTypeScale, fullHeight * 0.5)
                    : min(max(panelHeight, minHeight), fullHeight)

                ZStack(alignment: .bottom) {
                    // The map keeps a fixed inset so raising the sheet slides
                    // over it instead of squeezing the map contents.
                    MapCanvasView(store: store, bottomInset: minHeight)

                    CourseSheetView(
                        store: store,
                        height: $panelHeight,
                        currentHeight: height,
                        minHeight: minHeight,
                        maxHeight: fullHeight
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: height, alignment: .top)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: -3)
                }
                .onChange(of: store.selectedCourseID) { _, newValue in
                    let peekHeight = panelPeekHeight(fullHeight: fullHeight)
                    if newValue != nil, height < peekHeight {
                        withAnimation(.spring(duration: 0.32)) {
                            panelHeight = peekHeight
                        }
                    }
                }
                .onChange(of: store.selectedElement) { _, newValue in
                    let peekHeight = panelPeekHeight(fullHeight: fullHeight)
                    if newValue != nil, height < peekHeight {
                        withAnimation(.spring(duration: 0.32)) {
                            panelHeight = peekHeight
                        }
                    }
                }
            }
            // The map runs full-bleed to the top like Maps; the tab bar
            // already anchors the app identity, so no title bar is needed.
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            // Refreshes silently on every tab entry so renames and course
            // changes made in other tabs stay in sync.
            Task {
                await store.loadCourses(force: true)
            }
        }
    }
}

private enum MainTab: Hashable {
    case explore
    case register
    case library
}

#Preview {
    ContentView(store: CourseStore(courses: SeedData.courses))
}
