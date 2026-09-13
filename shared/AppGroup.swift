//
//  AppGroup.swift
//  birdo
//
//  Preferences and container shared between the iOS app and its widget.
//  On macOS there is no app group; the app keeps using standard defaults.
//

import Foundation

nonisolated enum AppGroup {
    static let identifier = "group.com.picosphere.birdo"

    static let serverURLKey = "serverBaseURL"
    static let widgetWindowKey = "widgetWindowMinutes"
    static let defaultWidgetWindow = 15

    /// Shared preferences store.
    static var defaults: UserDefaults {
        #if os(iOS)
        UserDefaults(suiteName: identifier) ?? .standard
        #else
        .standard
        #endif
    }

    /// Shared container directory, or nil when the app group is unavailable.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Configured server, or nil until onboarding has saved one.
    static var serverBaseURL: URL? {
        guard let stored = defaults.string(forKey: serverURLKey), !stored.isEmpty else { return nil }
        return URL(string: stored)
    }

    /// Default trailing window for the "most heard" widget, in minutes.
    static var widgetWindowMinutes: Int {
        let stored = defaults.integer(forKey: widgetWindowKey)
        return stored > 0 ? stored : defaultWidgetWindow
    }
}
