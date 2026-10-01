//
//  DailySummaryQuery.swift
//  birdo
//
//  Builds the BirdNET-Go daily species summary request and orders its rows.
//  Pure functions so they can be tested without a server.
//

import Foundation

nonisolated enum DailySummaryQuery {
    /// Server day containing `date`, as YYYY-MM-DD in `calendar`. The server's
    /// local day is assumed to match the device's, as elsewhere in the app.
    static func dateString(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func url(forDay day: String, base: URL) -> URL? {
        guard let endpoint = URL(string: "/api/v2/analytics/species/daily", relativeTo: base),
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)
        else { return nil }
        components.queryItems = [URLQueryItem(name: "date", value: day)]
        return components.url
    }

    /// A server `HH:MM:SS` (or `HH:MM`) clock time placed on `day`.
    static func time(_ clock: String, on day: Date, calendar: Calendar = .current) -> Date? {
        let fields = clock.split(separator: ":", omittingEmptySubsequences: false)
        let parts = fields.compactMap { Int($0) }
        guard parts.count == fields.count, (2...3).contains(parts.count),
              (0...23).contains(parts[0]), (0...59).contains(parts[1])
        else { return nil }
        let second = parts.count == 3 ? parts[2] : 0
        guard (0...60).contains(second) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = parts[0]
        components.minute = parts[1]
        components.second = second
        return calendar.date(from: components)
    }

    /// Most detections first. Ties go to the species heard most recently
    /// (zero-padded clock strings compare correctly), then to common name.
    static func rank(_ rows: [DailySpeciesSummary]) -> [DailySpeciesSummary] {
        rows.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            let l = lhs.latestHeard ?? "", r = rhs.latestHeard ?? ""
            if l != r { return l > r }
            return lhs.commonName < rhs.commonName
        }
    }

    static func fetch(base: URL, day: String, session: URLSession = .shared) async throws -> [DailySpeciesSummary] {
        guard let url = url(forDay: day, base: base) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([DailySpeciesSummary].self, from: data)
    }
}
