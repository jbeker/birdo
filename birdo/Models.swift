//
//  Models.swift
//  birdo
//
//  Types for the BirdNET-Go v2 API.
//

import Foundation

/// One entry in the SSE `pending` snapshot — a bird currently being heard.
struct PendingBird: Codable, Identifiable {
    var species: String          // common name
    var scientificName: String
    var thumbnail: String        // relative URL path, already percent-encoded
    var status: String           // "active" | "approved"
    var firstDetected: TimeInterval
    var lastUpdated: TimeInterval?
    var source: String           // display name, e.g. "Back Deck (Pi)"
    var sourceID: String?
    var hitCount: Int?
    var modelContributions: [ModelContribution]?

    /// Not from the server: set when the snapshot has dropped this bird but
    /// the card is being held on screen for the linger window.
    var isLingering = false

    /// Not from the server: bumped by the model when a bird returns while its
    /// previous card is still lingering, so the return gets a fresh card
    /// instead of re-brightening the dimmed one.
    var visit = 0

    struct ModelContribution: Codable {
        var modelID: String
        var maxConfidence: Double
    }

    enum CodingKeys: String, CodingKey {
        case species, scientificName, thumbnail, status, firstDetected,
             lastUpdated, source, sourceID, hitCount, modelContributions
    }

    // Do NOT include firstDetected here: the server renews it every ~15s
    // mid-song, which would churn card identity (and eat button clicks).
    var baseKey: String { "\(scientificName)|\(sourceID ?? source)" }
    var id: String { "\(baseKey)|\(visit)" }

    /// Best identification confidence across models, as a whole percentage.
    var confidencePercent: Int? {
        modelContributions?.map(\.maxConfidence).max()
            .map { Int(($0 * 100).rounded()) }
    }
}

extension PendingBird: Equatable {
    // Identity-plus-display comparison: lastUpdated/hitCount churn on every
    // ~1s snapshot and must not count as a change (would retrigger
    // animations), but shifts in what the card shows must.
    static func == (lhs: PendingBird, rhs: PendingBird) -> Bool {
        lhs.scientificName == rhs.scientificName
            && lhs.species == rhs.species
            && lhs.source == rhs.source
            && lhs.status == rhs.status
            && lhs.isLingering == rhs.isLingering
            && lhs.visit == rhs.visit
            && lhs.confidencePercent == rhs.confidencePercent
    }
}

/// A finalized detection, from the SSE `detection` event or /detections/recent.
struct RecentDetection: Codable {
    var id: Int
    var scientificName: String
    var birdImage: BirdImage?

    struct BirdImage: Codable {
        var authorName: String?
        var licenseName: String?
    }
}

/// One parsed server-sent event.
struct ServerSentEvent {
    var name: String
    var data: String
}
