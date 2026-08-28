//
//  CoCoApp.swift
//  CoCo
//
//  Created by 박준하 on 7/22/26.
//

import SwiftUI

@main
struct CoCoApp: App {
    @State private var session = SessionStore.shared

    var body: some Scene {
        WindowGroup {
            // The gate is here rather than inside a tab: without a token there
            // is no course list to show, only a way back in.
            if session.isSignedIn {
                ContentView()
            } else {
                SignInView {
                    session.didSignIn()
                }
            }
        }
    }
}
