//
//  birdoApp.swift
//  birdo
//
//  Created by Jeremy Beker on 9/8/26.
//

import SwiftUI

@main
struct birdoApp: App {
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
