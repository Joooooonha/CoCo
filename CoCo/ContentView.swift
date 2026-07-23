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
    @State private var sheetStage: ExploreSheetStage = .collapsed
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
                    sheetStage = .collapsed
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

    /// Scales the collapsed panel with the text size so larger Dynamic Type
    /// content is not clipped by a fixed height.
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

    private func collapsedPanelHeight(fullHeight: CGFloat) -> CGFloat {
        let base: CGFloat = store.selectedCourse != nil ? 252 : 190
        return min(base * panelTypeScale, fullHeight * 0.55)
    }

    private var exploreTab: some View {
        NavigationStack {
            GeometryReader { proxy in
                let panelHeight = collapsedPanelHeight(fullHeight: proxy.size.height)
                ZStack(alignment: .bottom) {
                    MapCanvasView(store: store, bottomInset: panelHeight)

                    coursePanel(fullHeight: proxy.size.height, collapsedHeight: panelHeight)
                }
            }
            .navigationTitle("CoCo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }

    private func coursePanel(fullHeight: CGFloat, collapsedHeight: CGFloat) -> some View {
        CourseSheetView(store: store, stage: $sheetStage)
            .frame(maxWidth: .infinity)
            .frame(height: sheetStage == .expanded ? fullHeight : collapsedHeight, alignment: .top)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 10, y: -3)
            .highPriorityGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height < -40 {
                            sheetStage = .expanded
                        } else if value.translation.height > 40 {
                            sheetStage = .collapsed
                        }
                    },
                including: sheetStage == .collapsed ? .all : .subviews
            )
            .animation(.spring(duration: 0.32), value: sheetStage)
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
