//
//  ExtrasArtworkRemoval.swift
//  Atlas
//

import Foundation

/// A header or search image marked to come off a language's page with the
/// next push (Delete…). It waits in Review & Push like a new file.
struct ExtrasArtworkRemoval: Codable, Hashable, Sendable, Identifiable {
    var place: StoreArtworkPlace
    var locale: String
    var markedAt: Date

    /// Review & Push's item ID, apart from the files' (`header-de-DE`).
    var id: String { Self.id(place, locale: locale) }

    static func id(_ place: StoreArtworkPlace, locale: String) -> String {
        "remove-\(place.rawValue)-\(locale)"
    }
}
