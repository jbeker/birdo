//
//  DailySpeciesRow.swift
//  birdo
//
//  One card in the Today list: a species heard today and how often.
//

import SwiftUI

struct DailySpeciesRow: View {
    let row: DailySpeciesSummary

    @Environment(DailySummaryModel.self) private var model
    @Environment(NowHearingModel.self) private var nowHearing

    var body: some View {
        BirdCard(
            commonName: row.commonName,
            scientificName: row.scientificName,
            imageURL: model.imageURL(for: row),
            linkURL: SpeciesLink.url(scientificName: row.scientificName, speciesCode: row.speciesCode),
            linkSiteName: SpeciesLink.siteName(speciesCode: row.speciesCode),
            photoCredit: photoCredit
        ) {
            if let when = model.lastHeard(for: row) {
                Label(String(localized: "Last heard \(when.formatted(date: .omitted, time: .shortened))"),
                      systemImage: "clock")
            } else {
                Label(String(localized: "Heard today"), systemImage: "clock")
            }
        } trailing: {
            VStack(spacing: 0) {
                Text(row.count, format: .number)
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text("today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 36)
            .help(String(localized: "\(row.count) detections today"))
        }
    }

    private var photoCredit: String {
        if let author = nowHearing.photoCredit[row.scientificName] {
            String(localized: "Photo: \(author)")
        } else {
            row.commonName
        }
    }
}
