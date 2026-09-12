//
//  DetectionStreamClient.swift
//  birdo
//
//  Minimal client for the BirdNET-Go SSE stream: decodes `pending`
//  snapshots and hands them to a callback. Used by the screen saver;
//  the app keeps its richer NowHearingModel.
//

import Foundation

final class DetectionStreamClient {
    let baseURL: URL
    let onSnapshot: @MainActor ([PendingBird]) -> Void

    init(baseURL: URL, onSnapshot: @escaping @MainActor ([PendingBird]) -> Void) {
        self.baseURL = baseURL
        self.onSnapshot = onSnapshot
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        // Idle timeout doubles as a liveness watchdog: `pending` fires ~1/sec
        // while birds are audible, so a dead connection errors out and
        // triggers a reconnect.
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = .infinity
        return URLSession(configuration: config)
    }()

    private let decoder = JSONDecoder()

    /// Connects and reconnects forever with exponential backoff.
    /// Returns only when the surrounding task is cancelled.
    func run() async {
        var backoff: Duration = .seconds(1)
        while !Task.isCancelled {
            do {
                try await connectOnce(resetBackoff: { backoff = .seconds(1) })
            } catch is CancellationError {
                return
            } catch {
                // fall through to reconnect
            }
            if Task.isCancelled { return }
            try? await Task.sleep(for: backoff)
            backoff = min(backoff * 2, .seconds(30))
        }
    }

    private func connectOnce(resetBackoff: () -> Void) async throws {
        guard let url = URL(string: "/api/v2/detections/stream", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // BirdNET-Go sends each event as an `event:` line followed by a single
        // `data:` line. Dispatch on `data:` rather than blank-line delimiters,
        // which AsyncLineSequence does not deliver reliably.
        var currentEvent = "message"
        for try await line in bytes.lines {
            resetBackoff()
            if line.hasPrefix("event:") {
                currentEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if currentEvent == "pending",
                   let snapshot = try? decoder.decode([PendingBird].self, from: Data(data.utf8)) {
                    let onSnapshot = onSnapshot
                    await MainActor.run { onSnapshot(snapshot) }
                }
                currentEvent = "message"
            }
        }
        throw URLError(.networkConnectionLost)  // stream ended; reconnect
    }
}
