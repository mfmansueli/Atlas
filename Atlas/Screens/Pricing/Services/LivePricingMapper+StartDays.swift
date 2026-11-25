//
//  LivePricingMapper+StartDays.swift
//  Atlas
//

import Foundation

extension LivePricingMapper {
    /// The start day ("2026-11-02") of each territory's price in effect
    /// today, where Apple gives one: the price history dates a change made
    /// outside Atlas by it. Same choice of price as `currentPrices`.
    static func currentStartDays(_ document: PricingAPIDocument<SubscriptionPriceAttributes>, today: String) -> [String: String] {
        var best: [String: String] = [:]
        for price in document.data {
            let start = price.attributes.startDate ?? ""
            guard start <= today, let territoryID = price.related("territory")?.id else { continue }
            if let existing = best[territoryID], existing > start { continue }
            best[territoryID] = start
        }
        return best.filter { !$0.value.isEmpty }
    }
}
