//
//  NowHearingModel.swift
//  birdo
//
//  Connects to the BirdNET-Go SSE stream and publishes the
//  "currently hearing" snapshot plus playback state.
//

import Foundation
import Observation

@Observable
final class NowHearingModel {
    enum ConnectionStatus {
        case connecting
        case live
        case reconnecting
    }

    private(set) var birds: [PendingBird] = []
    private(set) var status: ConnectionStatus = .connecting
    private(set) var latestDetectionID: [String: Int] = [:]  // scientificName -> detection id
    private(set) var photoCredit: [String: String] = [:]     // scientificName -> author

    let audioPlayer = AudioPlayer()

    /// Configured server, or nil until onboarding has saved one.
    var baseURL: URL? {
        guard let stored = UserDefaults.standard.string(forKey: "serverBaseURL"),
              !stored.isEmpty else { return nil }
        return URL(string: stored)
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        // Idle timeout doubles as a liveness watchdog: `pending` fires ~1/sec,
        // so a dead connection errors out and triggers a reconnect.
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = .infinity
        return URLSession(configuration: config)
    }()

    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var backoff: Duration = .seconds(1)

    // MARK: - Connection loop

    func run() async {
        guard baseURL != nil else { return }
        // Fresh start: run() is relaunched whenever the server URL changes.
        birds = []
        latestDetectionID = [:]
        photoCredit = [:]
        status = .connecting
        backoff = .seconds(1)
        audioPlayer.stop()

        await seedRecentDetections()
        while !Task.isCancelled {
            do {
                try await connectOnce()
            } catch is CancellationError {
                return
            } catch {
                // fall through to reconnect
            }
            if Task.isCancelled { return }
            status = .reconnecting
            try? await Task.sleep(for: backoff)
            backoff = min(backoff * 2, .seconds(30))
        }
    }

    private func connectOnce() async throws {
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
            if line.hasPrefix("event:") {
                currentEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                handle(ServerSentEvent(name: currentEvent, data: data))
                currentEvent = "message"
            }
        }
        throw URLError(.networkConnectionLost)  // stream ended; reconnect
    }

    private func handle(_ event: ServerSentEvent) {
        if status != .live {
            status = .live
        }
        backoff = .seconds(1)

        switch event.name {
        case "pending":
            guard let snapshot = try? decoder.decode([PendingBird].self, from: Data(event.data.utf8)) else { return }
            var sorted = snapshot.sorted { $0.firstDetected > $1.firstDetected }
            // Keep the card whose clip is playing, even if the server
            // snapshot has dropped the bird; it clears on the next
            // snapshot after playback stops.
            if let playing = audioPlayer.currentKey,
               !sorted.contains(where: { $0.scientificName == playing }),
               let held = birds.first(where: { $0.scientificName == playing }) {
                sorted.append(held)
                sorted.sort { $0.firstDetected > $1.firstDetected }
            }
            if sorted != birds {
                birds = sorted
            }
        case "detection":
            guard let detection = try? decoder.decode(RecentDetection.self, from: Data(event.data.utf8)) else { return }
            record(detection)
        default:
            break  // connected, heartbeat
        }
    }

    private func record(_ detection: RecentDetection) {
        latestDetectionID[detection.scientificName] = max(
            latestDetectionID[detection.scientificName] ?? 0, detection.id)
        if let author = detection.birdImage?.authorName {
            photoCredit[detection.scientificName] = author
        }
    }

    /// Populate clip IDs at launch so play buttons work for birds already mid-visit.
    private func seedRecentDetections() async {
        guard let url = URL(string: "/api/v2/detections/recent?limit=25", relativeTo: baseURL) else { return }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let detections = try? decoder.decode([RecentDetection].self, from: data)
        else { return }
        for detection in detections {
            record(detection)
        }
    }

    // MARK: - Playback

    func clipAvailable(for bird: PendingBird) -> Bool {
        latestDetectionID[bird.scientificName] != nil
    }

    func togglePlayback(for bird: PendingBird) {
        guard let id = latestDetectionID[bird.scientificName],
              let url = URL(string: "/api/v2/audio/\(id)", relativeTo: baseURL)
        else { return }
        audioPlayer.toggle(url: url, key: bird.scientificName)
    }

    // MARK: - Display helpers

    func imageURL(for bird: PendingBird) -> URL? {
        URL(string: bird.thumbnail, relativeTo: baseURL)
    }

    // MARK: - Server validation

    enum ServerValidationError: LocalizedError {
        case invalidURL
        case notBirdNetGo

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                String(localized: "That doesn't look like a valid URL.")
            case .notBirdNetGo:
                String(localized: "Reached the server, but it doesn't respond like a BirdNET-Go instance.")
            }
        }
    }

    /// Normalizes the entered address and confirms a BirdNET-Go API answers there.
    /// Returns the base URL to store.
    static func validate(serverURL rawInput: String) async throws -> URL {
        var address = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        while address.hasSuffix("/") {
            address.removeLast()
        }
        if !address.contains("://") {
            address = "https://" + address
        }
        guard let base = URL(string: address), base.host() != nil,
              let probe = URL(string: "/api/v2/detections/recent?limit=1", relativeTo: base)
        else {
            throw ServerValidationError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: probe)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              (try? JSONSerialization.jsonObject(with: data)) is [Any]
        else {
            throw ServerValidationError.notBirdNetGo
        }
        return base
    }
}
