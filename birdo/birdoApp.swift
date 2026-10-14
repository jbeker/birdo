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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppleScript's `launch application` sends an ascr/noop event instead
        // of the usual oapp event. AppKit treats that as "start without opening
        // windows", so SwiftUI skips presenting the WindowGroup even with
        // defaultLaunchBehavior(.presented). Detect that launch type and ask
        // the app to reopen itself, which is the same path a Dock click takes.
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == Self.appleScriptSuite,
              event.eventID == Self.launchEvent
        else { return }

        DispatchQueue.main.async {
            guard !NSApp.windows.contains(where: \.isVisible) else { return }
            let me = NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier)
            let reopen = NSAppleEventDescriptor(
                eventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEReopenApplication),
                targetDescriptor: me,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            _ = try? reopen.sendEvent(options: .noReply, timeout: 0)
        }
    }

    /// 'ascr' / 'noop': the event AppleScript's `launch` verb sends.
    private static let appleScriptSuite = fourCharCode("ascr")
    private static let launchEvent = fourCharCode("noop")

    private static func fourCharCode(_ s: String) -> AEEventClass {
        s.utf8.reduce(0) { ($0 << 8) | AEEventClass($1) }
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
