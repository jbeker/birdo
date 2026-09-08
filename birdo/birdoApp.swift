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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 300, minHeight: 320)
        }
        .defaultSize(width: 340, height: 440)

        Settings {
            SettingsView()
        }
    }
}
