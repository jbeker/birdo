//
//  DetectionQuery.swift
//  birdo
//
//  Builds the BirdNET-Go queries for a trailing time window and ranks the
//  species heard in it. Pure functions so they can be tested without a server.
//

import Foundation

nonisolated enum DetectionQuery {
    /// Rows per hourly request. Results are newest first, so a window only
    /// loses detections when the window alone holds more than this.
    static let pageSize = 1000

    nonisolated struct SpeciesCount: Codable, Identifiable, Equatable {
        var scientificName: String
        var commonName: String
        var count: Int
        var lastHeard: Date

        var id: String { scientificName }
    }

    /// One `queryType=hourly` request: hours `[hour, hour + duration)` of a
    /// single server day.
    nonisolated struct HourRange: Equatable {
        var date: String   // YYYY-MM-DD
        var hour: Int      // 0...23
        var duration: Int  // 1...24
    }

    /// Wall-clock hour ranges covering `[now - window, now]`, split per day.
    /// `date` and `hour` are interpreted in the server's local time, which is
    /// assumed to match `calendar`.
    static func hourRanges(now: Date, windowMinutes: Int, calendar: Calendar = .current) -> [HourRange] {
        let start = now.addingTimeInterval(-Double(max(1, windowMinutes)) * 60)
        guard var cursor = calendar.dateInterval(of: .hour, for: start)?.start,
              let last = calendar.dateInterval(of: .hour, for: now)?.start
        else { return [] }
        var ranges: [HourRange] = []
        while cursor <= last {
            let parts = calendar.dateComponents([.year, .month, .day, .hour], from: cursor)
            guard let year = parts.year, let month = parts.month, let day = parts.day, let hour = parts.hour else { break }
            let date = String(format: "%04d-%02d-%02d", year, month, day)
            if let index = ranges.indices.last, ranges[index].date == date {
                ranges[index].duration += 1
            } else {
                ranges.append(HourRange(date: date, hour: hour, duration: 1))
            }
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        return ranges
    }

    static func url(for range: HourRange, base: URL) -> URL? {
        guard let endpoint = URL(string: "/api/v2/detections", relativeTo: base),
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)
        else { return nil }
        components.queryItems = [
            URLQueryItem(name: "queryType", value: "hourly"),
            URLQueryItem(name: "date", value: range.date),
            URLQueryItem(name: "hour", value: String(range.hour)),
            URLQueryItem(name: "duration", value: String(min(24, max(1, range.duration)))),
            URLQueryItem(name: "numResults", value: String(pageSize)),
            URLQueryItem(name: "sortBy", value: "date_desc"),
        ]
        return components.url
    }

    static func imageURL(for scientificName: String, base: URL) -> URL? {
        guard let encoded = scientificName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "/api/v2/media/image/\(encoded)", relativeTo: base)
    }

    /// Fetches every detection in the hour ranges covering the window. The
    /// caller still filters on timestamp; hours are coarser than the window.
    static func fetchDetections(base: URL, now: Date = Date(), windowMinutes: Int,
                                calendar: Calendar = .current, session: URLSession = .shared) async throws -> [Detection] {
        let decoder = JSONDecoder()
        var all: [Detection] = []
        for range in hourRanges(now: now, windowMinutes: windowMinutes, calendar: calendar) {
            guard let url = url(for: range, base: base) else { throw URLError(.badURL) }
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            all += try decoder.decode(DetectionPage.self, from: data).data
        }
        return all
    }

    /// Resolves a detection's moment: the RFC 3339 `timestamp` when present,
    /// otherwise `date` + `time` read in the device's calendar.
    nonisolated struct TimestampParser {
        let calendar: Calendar
        private let iso: ISO8601DateFormatter

        init(calendar: Calendar = .current) {
            self.calendar = calendar
            iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
        }

        func date(of detection: Detection) -> Date? {
            if let stamp = detection.timestamp, let date = iso.date(from: stamp) {
                return date
            }
            let dateParts = detection.date.split(separator: "-").compactMap { Int($0) }
            let timeParts = detection.time.split(separator: ":").compactMap { Int($0) }
            guard dateParts.count == 3, timeParts.count >= 2 else { return nil }
            return calendar.date(from: DateComponents(
                year: dateParts[0], month: dateParts[1], day: dateParts[2],
                hour: timeParts[0], minute: timeParts[1], second: timeParts.count > 2 ? timeParts[2] : 0))
        }
    }

    /// Species heard at or after `since`, most detections first. Ties go to
    /// the species heard most recently, then to common name.
    static func rank(_ detections: [Detection], since: Date, parser: TimestampParser = TimestampParser()) -> [SpeciesCount] {
        var counts: [String: SpeciesCount] = [:]
        for detection in detections {
            guard let when = parser.date(of: detection), when >= since else { continue }
            if var entry = counts[detection.scientificName] {
                entry.count += 1
                entry.lastHeard = max(entry.lastHeard, when)
                counts[detection.scientificName] = entry
            } else {
                counts[detection.scientificName] = SpeciesCount(
                    scientificName: detection.scientificName, commonName: detection.commonName,
                    count: 1, lastHeard: when)
            }
        }
        return counts.values.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.lastHeard != rhs.lastHeard { return lhs.lastHeard > rhs.lastHeard }
            return lhs.commonName < rhs.commonName
        }
    }

    /// The most recently heard species regardless of the window.
    static func mostRecent(_ detections: [Detection], parser: TimestampParser = TimestampParser()) -> SpeciesCount? {
        var best: SpeciesCount?
        for detection in detections {
            guard let when = parser.date(of: detection) else { continue }
            if let current = best, current.lastHeard >= when { continue }
            best = SpeciesCount(scientificName: detection.scientificName, commonName: detection.commonName,
                                count: 1, lastHeard: when)
        }
        return best
    }
}
