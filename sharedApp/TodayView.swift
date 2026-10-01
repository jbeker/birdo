//
//  TodayView.swift
//  birdo
//
//  Every species heard today, most detections first. Shared by macOS and iOS.
//

import SwiftUI

struct TodayView: View {
    @Environment(DailySummaryModel.self) private var model
    @Environment(NowHearingModel.self) private var nowHearing
    @AppStorage(AppGroup.serverURLKey, store: AppGroup.defaults) private var serverBaseURL = ""

    var body: some View {
        Group {
            if !model.species.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.species) { row in
                            DailySpeciesRow(row: row)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                    .padding(10)
                }
            } else if !model.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.lastError != nil {
                MessageView(symbol: "wifi.exclamationmark",
                            title: String(localized: "Unreachable"),
                            subtitle: String(localized: "Couldn't reach \(host)"))
            } else {
                MessageView(symbol: "waveform",
                            title: String(localized: "Quiet so far"),
                            subtitle: String(localized: "Nothing heard yet today"))
            }
        }
        .animation(.snappy, value: model.species)
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.lastError != nil, !model.species.isEmpty {
                staleBanner
            }
        }
        .task(id: serverBaseURL) {
            await model.run()
        }
        .onChange(of: nowHearing.detectionTally) {
            model.refreshSoon()
        }
    }

    private var host: String {
        model.baseURL?.host() ?? "server"
    }

    /// Shown over a list that could not be refreshed.
    private var staleBanner: some View {
        Label {
            if let asOf = model.lastUpdated {
                Text("Couldn't reach \(host) · as of \(asOf.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("Couldn't reach \(host)")
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct MessageView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TodayView()
        .environment(DailySummaryModel())
        .environment(NowHearingModel())
        .frame(width: 340, height: 440)
}
