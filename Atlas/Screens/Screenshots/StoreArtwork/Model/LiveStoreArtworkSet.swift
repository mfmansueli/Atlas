//
//  LiveStoreArtworkSet.swift
//  Atlas
//

import Foundation

/// Every language's live header and search artwork, by locale code.
struct LiveStoreArtworkSet: Codable, Hashable, Sendable {
    var byLocale: [String: LiveStoreArtwork]

    init(byLocale: [String: LiveStoreArtwork] = [:]) {
        self.byLocale = byLocale
    }

    func image(_ place: StoreArtworkPlace, locale: String) -> LiveArtworkImage? {
        byLocale[locale]?[place]
    }
}
