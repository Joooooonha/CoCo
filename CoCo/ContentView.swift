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

    init(store: CourseStore = CourseStore()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("탐색", systemImage: "map.fill", value: MainTab.explore) {
                exploreTab
            }

            Tab("보관함", systemImage: "bookmark.fill", value: MainTab.library) {
                LibraryView()
            }
        }
        .task {
            await store.loadCourses()
        }
    }

    private var collapsedPanelHeight: CGFloat {
        store.selectedCourse != nil ? 252 : 190
    }

    private var exploreTab: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    MapCanvasView(store: store, bottomInset: collapsedPanelHeight)

                    coursePanel(fullHeight: proxy.size.height)
                }
            }
            .navigationTitle("CoCo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }

    private func coursePanel(fullHeight: CGFloat) -> some View {
        CourseSheetView(store: store, stage: $sheetStage)
            .frame(maxWidth: .infinity)
            .frame(height: sheetStage == .expanded ? fullHeight : collapsedPanelHeight, alignment: .top)
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
    case library
}

#Preview {
    ContentView(store: CourseStore(courses: SeedData.courses))
}
