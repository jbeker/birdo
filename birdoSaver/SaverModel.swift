//
//  SaverModel.swift
//  birdoSaver
//
//  Tracks which birds are on screen and where. Cards appear when a bird
//  enters the `pending` snapshot, at a random spot that doesn't overlap
//  the cards already showing, and fade out when the bird goes quiet.
//

import CoreGraphics
import Foundation
import Observation
import SwiftUI

@Observable
final class SaverModel {
    struct Card: Identifiable, Equatable {
        // Unique per appearance, NOT per detection key: reusing a stable
        // identity makes SwiftUI treat a departure + return as one card
        // changing position (it slides instead of fading).
        let id: UUID
        /// The snapshot entry this card represents (species|microphone).
        let key: String
        let species: String
        let scientificName: String
        let thumbnail: String
        let frame: CGRect
        let appearedAt: Date
        /// Set when the fade-out starts; the card is purged once invisible.
        var departingAt: Date?
    }

    private(set) var cards: [Card] = []
    private(set) var baseURL: URL?

    private var canvasSize: CGSize = .zero
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    /// Last time each detection key appeared in a snapshot.
    @ObservationIgnored private var lastSeen: [String: Date] = [:]

    /// A card younger than this is held even if the bird already went quiet,
    /// so a one-snapshot blip doesn't just flash.
    private static let minDwell: TimeInterval = 6
    /// A card older than this fades out even mid-song, then re-enters at a
    /// fresh position — keeps a long serenade from parking one card forever.
    private static let maxDwell: TimeInterval = 150
    /// Absent from snapshots for this long = the bird has gone quiet.
    private static let departGrace: TimeInterval = 5

    /// Arrivals are brisk; departures dissolve slowly.
    static let fadeIn: Animation = .easeOut(duration: 1.8)
    static let fadeOut: Animation = .easeInOut(duration: 4.5)
    private static let fadeOutDuration: TimeInterval = 4.5

    func start(canvasSize: CGSize) {
        stop()
        self.canvasSize = canvasSize
        // Re-read every start: the legacyScreenSaver host process is
        // long-lived, so a value cached at init would go stale when the
        // user changes it in the Options sheet.
        baseURL = SaverDefaults.serverBaseURL
        guard let baseURL else { return }

        let client = DetectionStreamClient(baseURL: baseURL) { [weak self] snapshot in
            self?.apply(snapshot)
        }
        streamTask = Task { await client.run() }

        // The server only emits `pending` while something is audible, so
        // card removal needs its own clock — otherwise the last cards of
        // the evening would stay up all night.
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        tickerTask?.cancel()
        tickerTask = nil
        cards = []
        lastSeen = [:]
    }

    // MARK: - Snapshot handling

    private func apply(_ snapshot: [PendingBird]) {
        let now = Date()
        for bird in snapshot {
            let key = bird.baseKey
            lastSeen[key] = now
            // One card per ongoing detection. A bird that went quiet and
            // returned is a new detection and gets a fresh card, even if
            // its previous card is still dissolving.
            if cards.contains(where: { $0.key == key && $0.departingAt == nil }) { continue }
            addCard(for: bird, at: now)
        }
    }

    private func addCard(for bird: PendingBird, at now: Date) {
        let size = cardSize
        // Departing cards still count as occupied — they're visible.
        let occupied = cards.map(\.frame)
        // No free spot means the screen is packed; the bird simply waits
        // for a later snapshot.
        guard let frame = Self.placeCard(size: size, avoiding: occupied, in: canvasSize) else { return }
        withAnimation(Self.fadeIn) {
            cards.append(Card(
                id: UUID(),
                key: bird.baseKey,
                species: bird.species,
                scientificName: bird.scientificName,
                thumbnail: bird.thumbnail,
                frame: frame,
                appearedAt: now
            ))
        }
    }

    private func tick() {
        let now = Date()

        // Start fades. The opacity change is what animates — the view stays
        // in the tree until it has fully dissolved, so the fade can't be
        // cut short by a removal.
        for index in cards.indices where cards[index].departingAt == nil {
            let card = cards[index]
            let age = now.timeIntervalSince(card.appearedAt)
            let quiet = now.timeIntervalSince(lastSeen[card.key] ?? .distantPast) > Self.departGrace
            guard age > Self.maxDwell || (quiet && age > Self.minDwell) else { continue }
            withAnimation(Self.fadeOut) {
                cards[index].departingAt = now
            }
        }

        // Purge cards that finished fading; they're invisible, so no animation.
        let purgeBefore = now.addingTimeInterval(-Self.fadeOutDuration - 0.3)
        let kept = cards.filter { card in
            guard let departingAt = card.departingAt else { return true }
            return departingAt > purgeBefore
        }
        if kept.count != cards.count {
            cards = kept
        }
    }

    // MARK: - Layout

    /// Card footprint, scaled down for small canvases (and the tiny
    /// System Settings preview).
    var cardSize: CGSize {
        let scale = min(1, max(0.22, canvasSize.width / 1600))
        return CGSize(width: 440 * scale, height: 190 * scale)
    }

    /// Random non-overlapping placement: rejection sampling first, then a
    /// shuffled coarse grid, then give up (screen full).
    static func placeCard(size: CGSize, avoiding occupied: [CGRect], in canvas: CGSize) -> CGRect? {
        let margin: CGFloat = 24
        let inset: CGFloat = min(40, canvas.width * 0.04)
        let region = CGRect(origin: .zero, size: canvas).insetBy(dx: inset, dy: inset)
        guard region.width >= size.width, region.height >= size.height else { return nil }

        func collides(_ rect: CGRect) -> Bool {
            occupied.contains { $0.insetBy(dx: -margin, dy: -margin).intersects(rect) }
        }

        for _ in 0..<40 {
            let origin = CGPoint(
                x: .random(in: region.minX...(region.maxX - size.width)),
                y: .random(in: region.minY...(region.maxY - size.height))
            )
            let rect = CGRect(origin: origin, size: size)
            if !collides(rect) { return rect }
        }

        let cols = max(1, Int(region.width / (size.width + margin)))
        let rows = max(1, Int(region.height / (size.height + margin)))
        let slots = (0..<rows).flatMap { row in (0..<cols).map { (row, $0) } }
        for (row, col) in slots.shuffled() {
            let rect = CGRect(
                x: region.minX + CGFloat(col) * (size.width + margin),
                y: region.minY + CGFloat(row) * (size.height + margin),
                width: size.width,
                height: size.height
            )
            if !collides(rect) { return rect }
        }
        return nil
    }
}
