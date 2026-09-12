//
//  ServerValidation.swift
//  birdo
//
//  Confirms an entered address points at a BirdNET-Go instance.
//  Shared between the app (onboarding/settings) and the screen saver
//  (options sheet).
//

import Foundation

enum ServerValidation {
    enum Error: LocalizedError {
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
            throw Error.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: probe)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              (try? JSONSerialization.jsonObject(with: data)) is [Any]
        else {
            throw Error.notBirdNetGo
        }
        return base
    }
}
