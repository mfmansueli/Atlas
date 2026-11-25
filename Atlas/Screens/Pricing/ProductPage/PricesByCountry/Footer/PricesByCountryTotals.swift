//
//  PricesByCountryTotals.swift
//  Atlas
//

import Foundation

/// The line under Prices by Country's table (board 73): "175 countries and
/// regions · 12 likely held back by price · 3 not pushed". The held-back
/// count shows only while the strategy suggests prices.
struct PricesByCountryTotals: Hashable, Sendable {
    var countryCount: Int
    /// Nil when there are no suggestions (Keep my prices, in-app purchases).
    var heldBackCount: Int?
    var notPushedCount: Int

    init(rows: [CountryPriceRow], showsSuggestions: Bool) {
        countryCount = rows.count
        heldBackCount = showsSuggestions ? rows.count(where: \.likelyHeldBack) : nil
        notPushedCount = rows.count(where: \.isPending)
    }

    var text: String {
        var parts = [
            countryCount == 1
                ? String(localized: "1 country or region", comment: "kind:label")
                : String(localized: "\(countryCount) countries and regions", comment: "kind:label"),
        ]
        if let heldBackCount {
            parts.append(String(localized: "\(heldBackCount) likely held back by price", comment: "kind:label"))
        }
        parts.append(String(localized: "\(notPushedCount) not pushed", comment: "kind:label"))
        return parts.joined(separator: " · ")
    }
}
