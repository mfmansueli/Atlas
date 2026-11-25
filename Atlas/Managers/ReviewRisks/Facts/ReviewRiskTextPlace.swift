//
//  ReviewRiskTextPlace.swift
//  Atlas
//

import Foundation

/// Where a store text goes, for the checks that read texts.
enum ReviewRiskTextPlace: String, Codable, Hashable, Sendable {
    /// A field of the version's store listing (`ReviewRiskText.field`).
    case storeListing
    /// A subscription's or in-app purchase's display name or description.
    case inAppText
    /// A screenshot caption.
    case caption
    /// An In-App Event's name or descriptions.
    case eventText
    /// A custom product page's promotional text.
    case productPage
    /// App Review's notes for the version.
    case reviewNotes
}
