//
//  TopBirdProvider.swift
//  birdoWidget
//
//  Fetches the trailing window of detections from BirdNET-Go and ranks the
//  species heard. Falls back to the last good result when offline.
//

import UIKit
import WidgetKit

struct TopBirdProvider: AppIntentTimelineProvider {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func placeholder(in context: Context) -> TopBirdEntry {
        .sample
    }

    func snapshot(for configuration: TopBirdConfigurationIntent, in context: Context) async -> TopBirdEntry {
        if context.isPreview {
            return .sample
        }
        return await load(configuration)
    }

    func timeline(for configuration: TopBirdConfigurationIntent, in context: Context) async -> Timeline<TopBirdEntry> {
        let entry = await load(configuration)
        let minutes: Int
        switch entry.state {
        case .unconfigured: minutes = 60
        case .unavailable: minutes = 5
        case .ranked, .quiet: minutes = entry.isStale ? 5 : max(5, entry.windowMinutes)
        }
        let refresh = Date().addingTimeInterval(Double(minutes) * 60)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func load(_ configuration: TopBirdConfigurationIntent) async -> TopBirdEntry {
        let now = Date()
        let window = configuration.window.minutes
        guard let base = AppGroup.serverBaseURL else {
            return TopBirdEntry(date: now, snapshot: nil, image: nil, isStale: false, host: "",
                                windowMinutes: window, state: .unconfigured)
        }
        let host = base.host() ?? base.absoluteString
        do {
            let detections = try await DetectionQuery.fetchDetections(
                base: base, now: now, windowMinutes: window, session: Self.session)
            let parser = DetectionQuery.TimestampParser()
            let since = now.addingTimeInterval(-Double(window) * 60)
            let ranked = DetectionQuery.rank(detections, since: since, parser: parser)
            let fallback = ranked.isEmpty ? DetectionQuery.mostRecent(detections, parser: parser) : nil
            let snapshot = WidgetSnapshot(asOf: now, windowMinutes: window, ranked: ranked, fallback: fallback)
            snapshot.save()
            let image = await headlineImage(for: snapshot, base: base, allowNetwork: true)
            return TopBirdEntry(date: now, snapshot: snapshot, image: image, isStale: false,
                                host: host, windowMinutes: window)
        } catch {
            guard let cached = WidgetSnapshot.load() else {
                return TopBirdEntry(date: now, snapshot: nil, image: nil, isStale: true,
                                    host: host, windowMinutes: window, state: .unavailable)
            }
            let image = await headlineImage(for: cached, base: base, allowNetwork: false)
            return TopBirdEntry(date: now, snapshot: cached, image: image, isStale: true,
                                host: host, windowMinutes: window)
        }
    }

    private func headlineImage(for snapshot: WidgetSnapshot, base: URL, allowNetwork: Bool) async -> UIImage? {
        guard let headline = snapshot.headline else { return nil }
        return await WidgetImageCache.image(for: headline.scientificName, base: base,
                                            session: Self.session, allowNetwork: allowNetwork)
    }
}
