//
//  LiveStoreArtwork.swift
//  Atlas
//

import Foundation

/// One language's header and search artwork as App Store Connect has
/// them; nil where it shows none.
struct LiveStoreArtwork: Codable, Hashable, Sendable {
    var header: LiveArtworkImage?
    var search: LiveArtworkImage?

    init(header: LiveArtworkImage? = nil, search: LiveArtworkImage? = nil) {
        self.header = header
        self.search = search
    }

    /// The images a localization's placements show, one per place: the
    /// iPhone group's when the place has several groups, as the preview
    /// draws an iPhone.
    init(images: [LiveArtworkImage]) {
        func pick(_ place: StoreArtworkPlace) -> LiveArtworkImage? {
            let mine = images.filter { $0.place == place }
            return mine.first { $0.placementGroup?.uppercased().contains("PHONE") == true } ?? mine.first
        }
        self.init(header: pick(.header), search: pick(.search))
    }

    subscript(place: StoreArtworkPlace) -> LiveArtworkImage? {
        switch place {
        case .header: header
        case .search: search
        }
    }
}
