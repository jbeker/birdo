//
//  birdoApp.swift
//  birdo
//
//  Created by Jeremy Beker on 9/8/26.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct birdoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = NowHearingModel()
    @State private var daily = DailySummaryModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(daily)
                .frame(minWidth: 300, minHeight: 320)
        }
        .defaultSize(width: 360, height: 480)
        // The app quits when its last window closes, so the window state saved
        // at quit never holds a window. Without these, a relaunch restores that
        // empty state and shows nothing until the Dock icon is clicked.
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
        }
    }
}
