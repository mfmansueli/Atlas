//
//  PricingMode+Strategy.swift
//  Atlas
//

import Foundation

/// The strategy pop-up's words (board 73): the app-wide pricing mode as
/// the banner offers it.
extension PricingMode {
    /// The pop-up's choices, in its order.
    static let strategyOrder: [PricingMode] = [.showSuggestions, .applyRecommended, .keepPrices]

    /// "Show Suggestions", "Apply Recommended Prices", "Keep Prices".
    var strategyTitle: String {
        switch self {
        case .showSuggestions: String(localized: "Show Suggestions", comment: "kind:menu-item")
        case .applyRecommended: String(localized: "Apply Recommended Prices", comment: "kind:menu-item")
        case .keepPrices: String(localized: "Keep Prices", comment: "kind:menu-item")
        }
    }

    /// The line under each choice.
    var strategyDetail: String {
        switch self {
        case .showSuggestions: String(localized: "A suggested price per country. Nothing changes until you accept.", comment: "kind:tooltip")
        case .applyRecommended: String(localized: "Adds them to Review & Push. You still push.", comment: "kind:tooltip")
        case .keepPrices: String(localized: "No price suggestions.", comment: "kind:hint")
        }
    }
}
