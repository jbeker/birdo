//
//  SpeciesLink.swift
//  birdo
//
//  Reference page for a species: eBird when the species code is known,
//  Wikipedia by scientific name otherwise.
//

import Foundation

nonisolated enum SpeciesLink {
    static func url(scientificName: String, speciesCode: String?) -> URL? {
        if let code = speciesCode, !code.isEmpty {
            return URL(string: "https://ebird.org/species/\(code)")
        }
        let page = scientificName.replacingOccurrences(of: " ", with: "_")
        guard let encoded = page.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://en.wikipedia.org/wiki/\(encoded)")
    }

    static func siteName(speciesCode: String?) -> String {
        speciesCode?.isEmpty == false ? "eBird" : "Wikipedia"
    }
}
