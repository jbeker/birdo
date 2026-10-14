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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // AppleScript's `launch application` sends an ascr/noop event instead
        // of the usual oapp event. AppKit treats that as "start without opening
        // windows", so SwiftUI skips presenting the WindowGroup even with
        // defaultLaunchBehavior(.presented). The event is not available as
        // NSAppleEventManager.currentAppleEvent in the launch callbacks, so
        // register a handler for it directly.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleLaunchEvent(_:withReply:)),
            forEventClass: Self.appleScriptSuite,
            andEventID: Self.launchEvent
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchLog("didFinishLaunching visible=\(visibleWindowCount)")
    }

    @objc private func handleLaunchEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        launchLog("received launch event visible=\(visibleWindowCount)")
        // Let launch finish, then ask the app to reopen itself if it still has
        // no window. That is the same path a Dock click takes.
        DispatchQueue.main.async {
            guard self.visibleWindowCount == 0 else { return }
            self.reopenSelf()
        }
    }

    private func reopenSelf() {
        let me = NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier)
        let reopen = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: me,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        do {
            _ = try reopen.sendEvent(options: .noReply, timeout: 0)
            launchLog("sent reopen; visible=\(visibleWindowCount)")
        } catch {
            launchLog("reopen send failed: \(error)")
        }
    }

    /// 'ascr' / 'noop': the event AppleScript's `launch` verb sends.
    private static let appleScriptSuite = fourCharCode("ascr")
    private static let launchEvent = fourCharCode("noop")

    private static func fourCharCode(_ s: String) -> AEEventClass {
        s.utf8.reduce(0) { ($0 << 8) | AEEventClass($1) }
    }

    private var visibleWindowCount: Int {
        NSApp.windows.filter(\.isVisible).count
    }

    /// Debug-only launch trail, written to the sandbox tmp directory
    /// (~/Library/Containers/com.picosphere.birdo/Data/tmp/birdo_launch.log).
    private func launchLog(_ message: String) {
        #if DEBUG
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("birdo_launch.log")
        let line = "\(Date()) pid=\(ProcessInfo.processInfo.processIdentifier) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
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
