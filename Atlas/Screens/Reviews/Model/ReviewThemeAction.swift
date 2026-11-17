//
//  ReviewThemeAction.swift
//  Atlas
//

import Foundation

/// The one thing a group of reviews ends in.
enum ReviewThemeAction: Hashable, Codable, Sendable {
    /// "Reply to All 38…": one message per language.
    case replyToAll
    /// "Open Pricing for Japan": Pricing with that territory (alpha-2)
    /// selected, or just Pricing.
    case openPricing(territory: String?)
    /// "Show Reviews": the list, filtered to the group.
    case showReviews
    /// "Suggest for Store Page": asks for store page words from what
    /// people praise.
    case suggestStorePage

    /// The name assistants use: `reply_to_all`, `open_pricing`,
    /// `show_reviews`, `suggest_store_page`.
    var code: String {
        switch self {
        case .replyToAll: "reply_to_all"
        case .openPricing: "open_pricing"
        case .showReviews: "show_reviews"
        case .suggestStorePage: "suggest_store_page"
        }
    }

    static let codes = ["reply_to_all", "open_pricing", "show_reviews", "suggest_store_page"]

    init?(code: String, territory: String?) {
        switch code {
        case "reply_to_all": self = .replyToAll
        case "open_pricing": self = .openPricing(territory: territory?.uppercased())
        case "show_reviews": self = .showReviews
        case "suggest_store_page": self = .suggestStorePage
        default: return nil
        }
    }
}
