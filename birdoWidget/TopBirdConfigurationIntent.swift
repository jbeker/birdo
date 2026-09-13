//
//  TopBirdConfigurationIntent.swift
//  birdoWidget
//
//  Per-widget override of the trailing window.
//

import AppIntents
import WidgetKit

enum WindowLength: Int, AppEnum {
    case appDefault = 0
    case ten = 10
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Window")

    static let caseDisplayRepresentations: [WindowLength: DisplayRepresentation] = [
        .appDefault: "App setting",
        .ten: "10 minutes",
        .fifteen: "15 minutes",
        .thirty: "30 minutes",
        .sixty: "60 minutes",
    ]

    /// Minutes to look back, falling back to the app-wide preference.
    var minutes: Int {
        self == .appDefault ? AppGroup.widgetWindowMinutes : rawValue
    }
}

struct TopBirdConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Most Heard"
    static let description = IntentDescription("Shows the bird heard most often in the last few minutes.")

    @Parameter(title: "Window", default: .appDefault)
    var window: WindowLength
}
