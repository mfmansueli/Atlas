//
//  PageShotsScreen.swift
//  Atlas
//

import Foundation

/// One screenshot of the page's set: which of the default set's screens it
/// shows (its capture) and its caption in each language. Its place in the
/// plan is its place in the set, and it takes the template's design for
/// that place, so a panorama still runs from left to right.
struct PageShotsScreen: Codable, Hashable, Sendable {
    /// The default set's slot (0-based) whose capture it shows.
    var slot: Int
    /// By locale.
    var captions: [String: PageShotsCaption]

    func caption(_ locale: String) -> PageShotsCaption? {
        captions[locale].flatMap { $0.isEmpty ? nil : $0 }
    }
}
