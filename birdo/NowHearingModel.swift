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
    private(set) var speciesCode: [String: String] = [:]     // scientificName -> eBird code

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
    /// Current visit number per bird/microphone (see PendingBird.visit).
    @ObservationIgnored private var visitNumber: [String: Int] = [:]

    // MARK: - Connection loop

    func run() async {
        guard baseURL != nil else { return }
        // Fresh start: run() is relaunched whenever the server URL changes.
        birds = []
        latestDetectionID = [:]
        photoCredit = [:]
        speciesCode = [:]
        departedAt = [:]
        firstSeen = [:]
        visitNumber = [:]
        status = .connecting
        backoff = .seconds(1)
        audioPlayer.stop()

        // Expire lingering cards on our own clock: the server only sends
        // pending events while something is being heard, so a quiet yard
        // would otherwise leave departed cards stuck until the next bird.
        let expiryTicker = Task { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                self?.expireLingeringCards()
            }
        }
        defer { expiryTicker.cancel() }

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
            // A bird returning while its previous card is still lingering
            // gets a fresh card (new visit); the dimmed one keeps aging
            // toward expiry below it.
            var merged: [PendingBird] = []
            for var bird in snapshot {
                bird.visit = visitNumber[bird.baseKey] ?? 0
                if birds.first(where: { $0.id == bird.id })?.isLingering == true {
                    bird.visit += 1
                    visitNumber[bird.baseKey] = bird.visit
                }
                merged.append(bird)
            }
            let liveIDs = Set(merged.map(\.id))
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
            // Active cards on top (newest arrival first); lingering cards sink
            // below them and age toward the bottom, so expiry always happens
            // at the bottom edge of the list.
            merged.sort {
                if $0.isLingering != $1.isLingering {
                    return !$0.isLingering
                }
                if $0.isLingering {
                    let d0 = departedAt[$0.id] ?? .distantPast
                    let d1 = departedAt[$1.id] ?? .distantPast
                    if d0 != d1 { return d0 > d1 }
                }
                return (firstSeen[$0.id] ?? $0.firstDetected) > (firstSeen[$1.id] ?? $1.firstDetected)
            }
            if merged != birds {
                birds = merged
            }
        case "detection":
            guard let detection = try? decoder.decode(RecentDetection.self, from: Data(event.data.utf8)) else { return }
            if let author = detection.birdImage?.authorName {
                photoCredit[detection.scientificName] = author
            }
            if let code = detection.speciesCode {
                speciesCode[detection.scientificName] = code
            }
            Task { await verifyAndRecord(detection) }
        default:
            break  // connected, heartbeat
        }
    }

    private func expireLingeringCards() {
        let now = Date()
        let kept = birds.filter { bird in
            guard bird.isLingering, let departed = departedAt[bird.id] else { return true }
            if audioPlayer.currentKey == bird.id { return true }
            if now.timeIntervalSince(departed) < Self.lingerInterval { return true }
            departedAt.removeValue(forKey: bird.id)
            firstSeen.removeValue(forKey: bird.id)
            return false
        }
        if kept != birds {
            birds = kept
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
            if let code = detection.speciesCode {
                speciesCode[detection.scientificName] = code
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

    /// Species page to open from the card: eBird when we've learned the
    /// species code from a detection, Wikipedia by scientific name otherwise.
    func databaseURL(for bird: PendingBird) -> URL? {
        if let code = speciesCode[bird.scientificName] {
            return URL(string: "https://ebird.org/species/\(code)")
        }
        let page = bird.scientificName.replacingOccurrences(of: " ", with: "_")
        guard let encoded = page.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://en.wikipedia.org/wiki/\(encoded)")
    }

    func databaseName(for bird: PendingBird) -> String {
        speciesCode[bird.scientificName] != nil ? "eBird" : "Wikipedia"
    }
}
