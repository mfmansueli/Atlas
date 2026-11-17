//
//  ReviewText.swift
//  Atlas
//

import Foundation

/// How Reviews writes stars, counts, days and storefronts.
enum ReviewText {
    /// "★★★☆☆".
    static func stars(_ rating: Int) -> String {
        let filled = max(0, min(rating, 5))
        return String(repeating: "★", count: filled) + String(repeating: "☆", count: 5 - filled)
    }

    /// "1 star", "3 stars", for VoiceOver.
    static func starsSpoken(_ rating: Int) -> String {
        rating == 1 ? String(localized: "1 star") : String(localized: "\(rating) stars")
    }

    /// "4.6", always with a point, as the App Store writes it.
    static func rating(_ value: Double) -> String {
        String(format: "%.1f", (value * 10).rounded() / 10)
    }

    /// "1,206".
    static func count(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// "1 review", "38 reviews".
    static func reviews(_ count: Int) -> String {
        count == 1 ? String(localized: "1 review") : String(localized: "\(Self.count(count)) reviews")
    }

    /// "1 reply", "38 replies".
    static func replies(_ count: Int) -> String {
        count == 1 ? String(localized: "1 reply") : String(localized: "\(Self.count(count)) replies")
    }

    /// "1 language", "9 languages".
    static func languages(_ count: Int) -> String {
        count == 1 ? String(localized: "1 language") : String(localized: "\(count) languages")
    }

    /// "Nov 15", in the Mac's time zone.
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Germany", "U.S.", "U.K.": a storefront in a list of several.
    static func shortTerritory(_ alpha2: String) -> String {
        switch alpha2.uppercased() {
        case "US": String(localized: "U.S.")
        case "GB": String(localized: "U.K.")
        default: TerritoryCatalog.standard.territory(alpha2: alpha2)?.name ?? alpha2
        }
    }

    /// The longest reply Apple takes.
    static let replyLimit = 5970

    /// "182 / 5,970".
    static func replyCounter(_ text: String) -> String {
        "\(count(text.count)) / \(count(replyLimit))"
    }
}
