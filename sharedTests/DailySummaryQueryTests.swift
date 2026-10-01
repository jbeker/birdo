//
//  DailySummaryQueryTests.swift
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

private func row(_ scientific: String, _ common: String, count: Int, latest: String?) -> DailySpeciesSummary {
    DailySpeciesSummary(scientificName: scientific, commonName: common, speciesCode: nil,
                        count: count, maxConfidence: nil, latestHeard: latest, thumbnailURL: nil)
}

@Suite struct DailySummaryQueryTests {
    let base = URL(string: "https://birds.example.com")!

    @Test func dateStringUsesCalendarDay() {
        // Shortly after midnight Eastern it is still the previous day in UTC.
        #expect(DailySummaryQuery.dateString(for: date(2026, 10, 1, 0, 30), calendar: eastern) == "2026-10-01")
        #expect(DailySummaryQuery.dateString(for: date(2026, 1, 5, 12, 0), calendar: eastern) == "2026-01-05")
    }

    @Test func dailyURL() throws {
        let url = try #require(DailySummaryQuery.url(forDay: "2026-10-01", base: base))
        #expect(url.host() == "birds.example.com")
        #expect(url.path() == "/api/v2/analytics/species/daily")
        #expect(url.query() == "date=2026-10-01")
    }

    @Test func placesClockTimeOnDay() {
        let day = date(2026, 10, 1, 15, 0)
        #expect(DailySummaryQuery.time("09:52:40", on: day, calendar: eastern) == date(2026, 10, 1, 9, 52, 40))
        #expect(DailySummaryQuery.time("00:00:00", on: day, calendar: eastern) == date(2026, 10, 1, 0, 0))
        #expect(DailySummaryQuery.time("23:59", on: day, calendar: eastern) == date(2026, 10, 1, 23, 59))
    }

    @Test(arguments: ["", "garbage", "25:00:00", "12:60:00", "12", "12:00:00:00", "1a:00:00"])
    func rejectsMalformedClock(_ clock: String) {
        #expect(DailySummaryQuery.time(clock, on: date(2026, 10, 1, 15, 0), calendar: eastern) == nil)
    }

    @Test func ranksByCountThenRecencyThenName() {
        let rows = [
            row("A a", "Alpha", count: 3, latest: "06:00:00"),
            row("B b", "Beta", count: 7, latest: "05:00:00"),
            row("C c", "Charlie", count: 3, latest: "09:30:00"),
            row("D d", "Delta", count: 3, latest: "06:00:00"),
            row("E e", "Echo", count: 1, latest: nil),
        ]
        let ranked = DailySummaryQuery.rank(rows)
        #expect(ranked.map(\.commonName) == ["Beta", "Charlie", "Alpha", "Delta", "Echo"])
    }

    @Test func decodesServerRow() throws {
        let json = """
        [{"scientific_name":"Cyanocitta cristata","common_name":"Blue Jay","species_code":"blujay","count":273,
        "hourly_counts":[0,0,0,0,0,13,97,52,76,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"high_confidence":true,
        "max_confidence":0.92,"first_heard":"09:52:40","latest_heard":"09:52:40",
        "thumbnail_url":"/api/v2/media/image/Cyanocitta%20cristata","days_since_first_seen":31},
        {"scientific_name":"Hapithus saltator","common_name":"Jumping Bush Cricket","count":1029,
        "hourly_counts":[],"max_confidence":0.99,"first_heard":"06:39:13","latest_heard":"06:39:13",
        "thumbnail_url":"/api/v2/media/image/Hapithus%20saltator"}]
        """
        let rows = try JSONDecoder().decode([DailySpeciesSummary].self, from: Data(json.utf8))
        #expect(rows.count == 2)
        #expect(rows[0].id == "Cyanocitta cristata")
        #expect(rows[0].speciesCode == "blujay")
        #expect(rows[0].count == 273)
        #expect(rows[0].latestHeard == "09:52:40")
        #expect(rows[0].thumbnailURL == "/api/v2/media/image/Cyanocitta%20cristata")
        #expect(rows[1].speciesCode == nil)
        #expect(URL(string: rows[1].thumbnailURL!, relativeTo: base)?.absoluteString
                == "https://birds.example.com/api/v2/media/image/Hapithus%20saltator")
    }
}

@Suite struct SpeciesLinkTests {
    @Test func prefersEBirdWhenCodeKnown() {
        #expect(SpeciesLink.url(scientificName: "Cyanocitta cristata", speciesCode: "blujay")?.absoluteString
                == "https://ebird.org/species/blujay")
        #expect(SpeciesLink.siteName(speciesCode: "blujay") == "eBird")
    }

    @Test func fallsBackToWikipedia() {
        #expect(SpeciesLink.url(scientificName: "Hapithus saltator", speciesCode: nil)?.absoluteString
                == "https://en.wikipedia.org/wiki/Hapithus_saltator")
        #expect(SpeciesLink.url(scientificName: "Hapithus saltator", speciesCode: "")?.absoluteString
                == "https://en.wikipedia.org/wiki/Hapithus_saltator")
        #expect(SpeciesLink.siteName(speciesCode: nil) == "Wikipedia")
    }
}
