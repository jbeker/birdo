//
//  BirdoiOSApp.swift
//  birdo
//
//  iOS entry point. Reloads the widget when the app leaves the foreground so
//  it reflects anything learned while the app was open.
//

import SwiftUI
import WidgetKit

@main
struct BirdoiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = NowHearingModel()
    @State private var daily = DailySummaryModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(daily)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
