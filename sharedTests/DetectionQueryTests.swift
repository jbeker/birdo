//
//  DetectionQueryTests.swift
//  sharedTests
//

import Foundation
import Testing

private let eastern: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
    eastern.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
}

private func detection(_ id: Int, _ scientific: String, _ common: String, at when: Date,
                       withTimestamp: Bool = true) -> Detection {
    let parts = eastern.dateComponents([.year, .month, .day, .hour, .minute, .second], from: when)
    let stamp = ISO8601DateFormatter()
    stamp.timeZone = eastern.timeZone
    stamp.formatOptions = [.withInternetDateTime]
    return Detection(
        id: id,
        date: String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!),
        time: String(format: "%02d:%02d:%02d", parts.hour!, parts.minute!, parts.second!),
        timestamp: withTimestamp ? stamp.string(from: when) : nil,
        scientificName: scientific, commonName: common, speciesCode: nil, confidence: 0.9)
}

@Suite struct HourRangeTests {
    @Test func windowInsideOneHour() {
        let ranges = DetectionQuery.hourRanges(now: date(2026, 9, 13, 15, 50), windowMinutes: 15, calendar: eastern)
        #expect(ranges == [.init(date: "2026-09-13", hour: 15, duration: 1)])
    }

    @Test func windowSpanningHourBoundary() {
        let ranges = DetectionQuery.hourRanges(now: date(2026, 9, 13, 15, 5), windowMinutes: 15, calendar: eastern)
        #expect(ranges == [.init(date: "2026-09-13", hour: 14, duration: 2)])
    }

    @Test func windowSpanningMidnight() {
        let ranges = DetectionQuery.hourRanges(now: date(2026, 9, 13, 0, 5), windowMinutes: 30, calendar: eastern)
        #expect(ranges == [
            .init(date: "2026-09-12", hour: 23, duration: 1),
            .init(date: "2026-09-13", hour: 0, duration: 1),
        ])
    }

    @Test func hourlyURL() throws {
        let base = URL(string: "https://birds.example.com")!
        let url = try #require(DetectionQuery.url(for: .init(date: "2026-09-13", hour: 7, duration: 2), base: base))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.path() == "/api/v2/detections")
        #expect(items.contains(URLQueryItem(name: "queryType", value: "hourly")))
        #expect(items.contains(URLQueryItem(name: "date", value: "2026-09-13")))
        #expect(items.contains(URLQueryItem(name: "hour", value: "7")))
        #expect(items.contains(URLQueryItem(name: "duration", value: "2")))
    }

    @Test func imageURLEncodesSpaces() {
        let base = URL(string: "https://birds.example.com")!
        let url = DetectionQuery.imageURL(for: "Spinus tristis", base: base)
        #expect(url?.absoluteString == "https://birds.example.com/api/v2/media/image/Spinus%20tristis")
    }
}

@Suite struct RankingTests {
    let now = date(2026, 9, 13, 15, 50)
    var parser: DetectionQuery.TimestampParser { .init(calendar: eastern) }

    @Test func countsWithinWindowOnly() {
        let detections = [
            detection(1, "Spinus tristis", "American Goldfinch", at: now.addingTimeInterval(-60)),
            detection(2, "Spinus tristis", "American Goldfinch", at: now.addingTimeInterval(-300)),
            detection(3, "Cardinalis cardinalis", "Northern Cardinal", at: now.addingTimeInterval(-120)),
            detection(4, "Cardinalis cardinalis", "Northern Cardinal", at: now.addingTimeInterval(-3000)),  // outside
        ]
        let ranked = DetectionQuery.rank(detections, since: now.addingTimeInterval(-900), parser: parser)
        #expect(ranked.map(\.scientificName) == ["Spinus tristis", "Cardinalis cardinalis"])
        #expect(ranked.map(\.count) == [2, 1])
        #expect(ranked[0].lastHeard == now.addingTimeInterval(-60))
    }

    @Test func tiesGoToMostRecent() {
        let detections = [
            detection(1, "A a", "Alpha", at: now.addingTimeInterval(-500)),
            detection(2, "B b", "Beta", at: now.addingTimeInterval(-100)),
        ]
        let ranked = DetectionQuery.rank(detections, since: now.addingTimeInterval(-900), parser: parser)
        #expect(ranked.map(\.commonName) == ["Beta", "Alpha"])
    }

    @Test func fallsBackToDateAndTimeWhenTimestampMissing() throws {
        let when = now.addingTimeInterval(-90)
        let d = detection(1, "A a", "Alpha", at: when, withTimestamp: false)
        #expect(d.timestamp == nil)
        let parsed = try #require(parser.date(of: d))
        #expect(parsed == when)
    }

    @Test func mostRecentIgnoresWindow() throws {
        let detections = [
            detection(1, "A a", "Alpha", at: now.addingTimeInterval(-5000)),
            detection(2, "B b", "Beta", at: now.addingTimeInterval(-2000)),
        ]
        let recent = try #require(DetectionQuery.mostRecent(detections, parser: parser))
        #expect(recent.commonName == "Beta")
        #expect(DetectionQuery.rank(detections, since: now.addingTimeInterval(-900), parser: parser).isEmpty)
    }

    @Test func decodesServerEnvelope() throws {
        let json = """
        {"data":[{"id":84567,"date":"2026-09-13","time":"15:45:17","timestamp":"2026-09-13T15:45:17-04:00",
        "speciesCode":"amegfi","scientificName":"Spinus tristis","commonName":"American Goldfinch","confidence":0.28}],
        "total":221,"limit":2,"offset":0}
        """
        let page = try JSONDecoder().decode(DetectionPage.self, from: Data(json.utf8))
        #expect(page.data.count == 1)
        #expect(page.total == 221)
        #expect(parser.date(of: page.data[0]) == date(2026, 9, 13, 15, 45, 17))
    }
}
