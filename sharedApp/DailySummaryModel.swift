//
//  DailySummaryModel.swift
//  birdo
//
//  Species heard so far today with detection counts, from the BirdNET-Go
//  daily summary. Refreshes while the Today tab is on screen. Shared by the
//  macOS and iOS apps.
//

import Foundation
import Observation

@MainActor
@Observable
final class DailySummaryModel {
    /// Most detections first.
    private(set) var species: [DailySpeciesSummary] = []
    /// Local day the current list describes.
    private(set) var day = Date()
    private(set) var isLoading = false
    /// False until the first fetch for the current server has finished.
    private(set) var hasLoaded = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?

    /// Configured server, or nil until onboarding has saved one.
    var baseURL: URL? { AppGroup.serverBaseURL }

    @ObservationIgnored private let session = URLSession(configuration: .default)
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private var loadedBase: URL?
    private static let refreshInterval: Duration = .seconds(60)
    private static let debounce: Duration = .seconds(2)

    /// Refreshes now and then once a minute until cancelled. Meant to run only
    /// while the Today tab is visible; the tab's `.task` provides the lifetime.
    func run() async {
        if loadedBase != baseURL {
            // Server changed: do not keep showing another server's day.
            species = []
            hasLoaded = false
            lastError = nil
            lastUpdated = nil
        }
        defer {
            pendingRefresh?.cancel()
            pendingRefresh = nil
        }
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: Self.refreshInterval)
            } catch {
                return
            }
        }
    }

    /// Coalesces a burst of detections into one refresh a moment later.
    func refreshSoon() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    func refresh() async {
        guard let base = baseURL else {
            species = []
            hasLoaded = true
            return
        }
        // Resolved per call so the list resets itself after midnight.
        let now = Date()
        let dayString = DailySummaryQuery.dateString(for: now)
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await DailySummaryQuery.fetch(base: base, day: dayString, session: session)
            guard baseURL == base else { return }  // server changed mid-flight
            let ranked = DailySummaryQuery.rank(fetched)
            day = now
            if ranked != species {
                species = ranked
            }
            loadedBase = base
            lastUpdated = now
            lastError = nil
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            // Keep the previous list; the view marks it as stale.
            lastError = error.localizedDescription
            hasLoaded = true
        }
    }

    // MARK: - Display helpers

    func imageURL(for row: DailySpeciesSummary) -> URL? {
        guard let base = baseURL else { return nil }
        if let path = row.thumbnailURL, let url = URL(string: path, relativeTo: base) {
            return url
        }
        return DetectionQuery.imageURL(for: row.scientificName, base: base)
    }

    func lastHeard(for row: DailySpeciesSummary) -> Date? {
        guard let clock = row.latestHeard else { return nil }
        return DailySummaryQuery.time(clock, on: day)
    }
}
