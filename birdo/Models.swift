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

    var id: String { "\(scientificName)|\(sourceID ?? source)" }
}

extension PendingBird: Equatable {
    // Identity-only comparison: lastUpdated/hitCount churn on every ~1s snapshot
    // and must not count as a change (would retrigger animations).
    static func == (lhs: PendingBird, rhs: PendingBird) -> Bool {
        lhs.scientificName == rhs.scientificName
            && lhs.species == rhs.species
            && lhs.source == rhs.source
            && lhs.status == rhs.status
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
