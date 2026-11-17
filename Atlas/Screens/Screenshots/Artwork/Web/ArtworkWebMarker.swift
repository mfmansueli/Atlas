//
//  ArtworkWebMarker.swift
//  Atlas
//

import Foundation

/// What a Claude Design page marks with `data-al` for Atlas to fill
/// in each language: the placement's own text, the app's name and icon,
/// the picked captures (`data-slot`, from 1), and the page's own words
/// (`text`), written by Claude Design in every language as children with
/// `lang`, of which Atlas keeps the language's.
enum ArtworkWebMarker: String, CaseIterable, Codable, Hashable, Sendable {
    case headline
    case appName
    case icon
    case capture
    case text

    /// `data-al="headline"`.
    var attribute: String { "data-al=\"\(rawValue)\"" }

    /// Text Atlas writes into the element.
    var isText: Bool { self == .headline || self == .appName || self == .text }
}
