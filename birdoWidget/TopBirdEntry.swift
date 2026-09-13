//
//  TopBirdEntry.swift
//  birdoWidget
//

import UIKit
import WidgetKit

/// Last successful widget fetch, kept in the app group so the widget can
/// keep showing something when the server is unreachable.
struct WidgetSnapshot: Codable {
    var asOf: Date
    var windowMinutes: Int
    var ranked: [DetectionQuery.SpeciesCount]
    /// Most recent species overall, used when `ranked` is empty.
    var fallback: DetectionQuery.SpeciesCount?

    var headline: DetectionQuery.SpeciesCount? { ranked.first ?? fallback }

    private static var fileURL: URL {
        let directory = AppGroup.containerURL
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return directory.appending(path: "widget-last.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}

struct TopBirdEntry: TimelineEntry {
    enum State {
        case unconfigured   // no server saved yet
        case unavailable    // fetch failed and nothing cached
        case ranked         // birds heard in the window
        case quiet          // nothing in the window; showing the last bird heard
    }

    var date: Date
    var state: State
    var windowMinutes: Int
    var ranked: [DetectionQuery.SpeciesCount]
    var headline: DetectionQuery.SpeciesCount?
    var image: UIImage?
    var asOf: Date
    var isStale: Bool
    var host: String

    init(date: Date, snapshot: WidgetSnapshot?, image: UIImage?, isStale: Bool, host: String,
         windowMinutes: Int, state: State? = nil) {
        self.date = date
        self.windowMinutes = windowMinutes
        ranked = snapshot?.ranked ?? []
        headline = snapshot?.headline
        self.image = image
        asOf = snapshot?.asOf ?? date
        self.isStale = isStale
        self.host = host
        if let state {
            self.state = state
        } else if let snapshot {
            self.state = snapshot.ranked.isEmpty ? .quiet : .ranked
        } else {
            self.state = .unavailable
        }
    }

    /// Sample data for the widget gallery and placeholders.
    static var sample: TopBirdEntry {
        let now = Date()
        let ranked = [
            DetectionQuery.SpeciesCount(scientificName: "Cardinalis cardinalis", commonName: "Northern Cardinal",
                                        count: 12, lastHeard: now.addingTimeInterval(-40)),
            DetectionQuery.SpeciesCount(scientificName: "Poecile carolinensis", commonName: "Carolina Chickadee",
                                        count: 7, lastHeard: now.addingTimeInterval(-200)),
            DetectionQuery.SpeciesCount(scientificName: "Cyanocitta cristata", commonName: "Blue Jay",
                                        count: 3, lastHeard: now.addingTimeInterval(-500)),
        ]
        let snapshot = WidgetSnapshot(asOf: now, windowMinutes: 15, ranked: ranked, fallback: nil)
        return TopBirdEntry(date: now, snapshot: snapshot, image: nil, isStale: false,
                            host: "birdnet.example.com", windowMinutes: 15)
    }
}
