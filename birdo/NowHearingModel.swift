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

    /// How long a card stays on screen after the server stops hearing the bird.
    private static let lingerInterval: TimeInterval = 10
    @ObservationIgnored private var departedAt: [String: Date] = [:]
    /// Sort position per card, pinned at first appearance — the server renews
    /// firstDetected every ~15s mid-song, which would otherwise reshuffle cards.
    @ObservationIgnored private var firstSeen: [String: TimeInterval] = [:]

    // MARK: - Connection loop

    func run() async {
        guard baseURL != nil else { return }
        // Fresh start: run() is relaunched whenever the server URL changes.
        birds = []
        latestDetectionID = [:]
        photoCredit = [:]
        departedAt = [:]
        firstSeen = [:]
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
            let now = Date()
            var merged = snapshot
            let liveIDs = Set(snapshot.map(\.id))
            for id in liveIDs {
                departedAt.removeValue(forKey: id)
            }
            // Hold departed cards for the linger window (dimmed), and for
            // as long as their clip is playing.
            for var bird in birds where !liveIDs.contains(bird.id) {
                let departed = departedAt[bird.id] ?? now
                departedAt[bird.id] = departed
                if audioPlayer.currentKey == bird.id
                    || now.timeIntervalSince(departed) < Self.lingerInterval {
                    bird.isLingering = true
                    merged.append(bird)
                } else {
                    departedAt.removeValue(forKey: bird.id)
                }
            }
            for bird in merged where firstSeen[bird.id] == nil {
                firstSeen[bird.id] = bird.firstDetected
            }
            let mergedIDs = Set(merged.map(\.id))
            firstSeen = firstSeen.filter { mergedIDs.contains($0.key) }
            merged.sort {
                (firstSeen[$0.id] ?? $0.firstDetected) > (firstSeen[$1.id] ?? $1.firstDetected)
            }
            if merged != birds {
                birds = merged
            }
        case "detection":
            guard let detection = try? decoder.decode(RecentDetection.self, from: Data(event.data.utf8)) else { return }
            if let author = detection.birdImage?.authorName {
                photoCredit[detection.scientificName] = author
            }
            Task { await verifyAndRecord(detection) }
        default:
            break  // connected, heartbeat
        }
    }

    /// Records a detection id only once its clip actually answers on the
    /// server — the WAV is written a few seconds after the detection event,
    /// and enabling the play button early makes it silently do nothing.
    private func verifyAndRecord(_ detection: RecentDetection) async {
        guard let base = baseURL,
              detection.id > (latestDetectionID[detection.scientificName] ?? 0),
              let url = URL(string: "/api/v2/audio/\(detection.id)", relativeTo: base)
        else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        for attempt in 0..<6 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(2))
            }
            guard let (_, response) = try? await session.data(for: request),
                  let statusCode = (response as? HTTPURLResponse)?.statusCode
            else { continue }
            // 405: server doesn't support HEAD; assume the clip is there.
            if statusCode == 200 || statusCode == 405 {
                guard baseURL == base,
                      detection.id > (latestDetectionID[detection.scientificName] ?? 0)
                else { return }
                latestDetectionID[detection.scientificName] = detection.id
                return
            }
        }
    }

    /// Populate clip IDs at launch so play buttons work for birds already mid-visit.
    private func seedRecentDetections() async {
        guard let url = URL(string: "/api/v2/detections/recent?limit=25", relativeTo: baseURL) else { return }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let detections = try? decoder.decode([RecentDetection].self, from: data)
        else { return }
        // Verify only the newest detection per species.
        var newest: [String: RecentDetection] = [:]
        for detection in detections {
            if let author = detection.birdImage?.authorName {
                photoCredit[detection.scientificName] = author
            }
            if detection.id > (newest[detection.scientificName]?.id ?? 0) {
                newest[detection.scientificName] = detection
            }
        }
        for detection in newest.values {
            Task { await verifyAndRecord(detection) }
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
        // Key by card id, not species: the same species heard on two
        // microphones must not share a play/stop state.
        audioPlayer.toggle(url: url, key: bird.id)
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
