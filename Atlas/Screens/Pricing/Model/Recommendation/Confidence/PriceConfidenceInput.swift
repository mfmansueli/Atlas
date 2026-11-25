//
//  PriceConfidenceInput.swift
//  Atlas
//

import Foundation

/// Everything HowSure looks at for one country's price suggestion.
struct PriceConfidenceInput: Hashable, Sendable {
    /// "Brazil", for the reason line.
    var territoryName: String
    var availability: PricingSalesData.Availability
    /// How far the purchasing-power value behind the suggestion is real.
    var indexTrust: PriceIndexTrust
    /// The index edition's year, for a stale value's reason.
    var indexEditionYear: Int?
    /// Apple's own price points are here, not simulated ones.
    var hasRealGrid: Bool
    /// The country's last 90 days.
    var signal: SalesSignal?
    /// The country's conversion pooled with its region's.
    var pooled: PooledConversion?
    var priorChange: PriorPriceChange?
    /// Count trial starts (the product has trials), else every start.
    var usesTrials = true
    /// The last day the numbers cover, for the 28 days after a change.
    var asOf: Date
    /// A finished price test in the territory's region: a measured change too.
    var priceTest: PriceTestEvidence?
}
