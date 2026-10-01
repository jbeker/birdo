//
//  ContentView.swift
//  birdo
//
//  Tabs for the live "Now Hearing" list and the "Today" summary. Shared by
//  macOS and iOS.
//

import SwiftUI

struct ContentView: View {
    @Environment(NowHearingModel.self) private var model
    @AppStorage(AppGroup.serverURLKey, store: AppGroup.defaults) private var serverBaseURL = ""
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    var body: some View {
        if serverBaseURL.isEmpty {
            OnboardingView()
        } else {
            tabs
                // The stream belongs to the tab container, not the Now Hearing
                // tab: a task on the tab's content would be cancelled every
                // time the Today tab is selected.
                .task(id: serverBaseURL) {
                    await model.run()
                }
        }
    }

    private var tabs: some View {
        #if os(iOS)
        TabView {
            Tab("Now Hearing", systemImage: "waveform") {
                NavigationStack {
                    NowHearingView()
                        .navigationTitle("Now Hearing")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsToolbar }
                }
            }
            Tab("Today", systemImage: "chart.bar") {
                NavigationStack {
                    TodayView()
                        .navigationTitle("Today")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsToolbar }
                }
            }
        }
        .tabViewBottomAccessory {
            StatusIndicator(status: model.status)
                .padding(.horizontal, 12)
        }
        .sheet(isPresented: $showingSettings) {
            IOSSettingsView()
        }
        #else
        TabView {
            Tab("Now Hearing", systemImage: "waveform") {
                NowHearingView()
            }
            Tab("Today", systemImage: "chart.bar") {
                TodayView()
            }
        }
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
        #endif
    }

    #if os(iOS)
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape") {
                showingSettings = true
            }
        }
    }
    #endif
}

/// Live list of birds currently being heard.
struct NowHearingView: View {
    @Environment(NowHearingModel.self) private var model

    var body: some View {
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
        .environment(DailySummaryModel())
        .frame(width: 360, height: 480)
}
