//
//  AquaPiViewerApp.swift
//  AquaPiViewer
//
//  Created by 池田洋平 on 2026/06/07.
//

import SwiftUI

@main
struct AquaPiViewerApp: App {
    init() {
        AppEventLogger().log("app_launched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
