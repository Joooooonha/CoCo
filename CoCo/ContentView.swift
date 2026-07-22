//
//  ContentView.swift
//  CoCo
//
//  Created by 박준하 on 7/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var store = CourseStore()
    @State private var isCourseSheetPresented = true
    @State private var selectedDetent: PresentationDetent = .height(190)

    var body: some View {
        NavigationStack {
            MapCanvasView(store: store)
                .navigationTitle("CoCo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .sheet(isPresented: $isCourseSheetPresented) {
            CourseSheetView(store: store, selectedDetent: $selectedDetent)
                .presentationDetents([.height(190), .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(190)))
                .interactiveDismissDisabled()
        }
    }
}

#Preview {
    ContentView()
}
