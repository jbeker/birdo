//
//  ContentView.swift
//  birdo
//
//  Created by Jeremy Beker on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(NowHearingModel.self) private var model
    @AppStorage("serverBaseURL") private var serverBaseURL = ""

    var body: some View {
        if serverBaseURL.isEmpty {
            OnboardingView()
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        Group {
            if model.birds.isEmpty {
                EmptyStateView(status: model.status, host: model.baseURL?.host() ?? "server")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.birds) { bird in
                            BirdCardView(bird: bird)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                    .padding(10)
                }
            }
        }
        .animation(.snappy, value: model.birds)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                StatusIndicator(status: model.status)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
        .task(id: serverBaseURL) {
            await model.run()
        }
    }
}

private struct StatusIndicator: View {
    let status: NowHearingModel.ConnectionStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .connecting: .orange
        case .live: .green
        case .reconnecting: .red
        }
    }

    private var statusLabel: String {
        switch status {
        case .connecting: String(localized: "Connecting…")
        case .live: String(localized: "Live")
        case .reconnecting: String(localized: "Reconnecting…")
        }
    }
}

private struct EmptyStateView: View {
    let status: NowHearingModel.ConnectionStatus
    let host: String

    var body: some View {
        VStack(spacing: 12) {
            if status == .reconnecting {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("Reconnecting…")
                    .font(.title3.weight(.medium))
                Text("Trying to reach \(host)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("Listening…")
                    .font(.title3.weight(.medium))
                Text("No birds detected right now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environment(NowHearingModel())
        .frame(width: 340, height: 440)
}
