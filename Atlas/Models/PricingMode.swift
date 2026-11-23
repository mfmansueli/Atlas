//
//  PricingMode.swift
//  Atlas
//

import Foundation

/// How much Atlas gets involved in an app's prices. Picked per app
/// the first time Pricing opens (default in Settings) and switchable any
/// time from the Pricing section bar.
enum PricingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Translation only: prices are shown read-only and never proposed.
    case keepPrices
    /// Each territory shows a suggestion next to its price; nothing is
    /// queued until "Apply".
    case showSuggestions
    /// Every proposed price is filled with the suggestion and waits in
    /// Review & Push.
    case applyRecommended

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keepPrices: String(localized: "Keep my prices")
        case .showSuggestions: String(localized: "Show suggestions")
        case .applyRecommended: String(localized: "Apply suggested prices")
        }
    }

    var summary: String {
        switch self {
        case .keepPrices:
            String(localized: "Translate only. Prices stay as they are, with no suggestions.")
        case .showSuggestions:
            String(localized: "Suggested price, reason and confidence per territory. Nothing changes until you apply it.")
        case .applyRecommended:
            String(localized: "Every territory gets its suggested price. Review before you push.")
        }
    }

    var systemImage: String {
        switch self {
        case .keepPrices: "lock"
        case .showSuggestions: "lightbulb"
        case .applyRecommended: "wand.and.stars"
        }
    }

    /// Whether suggestions, the "held back" count and price indicators show.
    var showsSuggestions: Bool { self != .keepPrices }
}
