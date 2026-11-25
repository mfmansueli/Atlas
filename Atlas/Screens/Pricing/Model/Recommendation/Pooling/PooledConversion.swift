//
//  PooledConversion.swift
//  Atlas
//

import Foundation

/// One country's conversion (page view → start) after pooling: its own
/// 90 days shrunk toward its region's rate (`ConversionPooling`).
struct PooledConversion: Hashable, Sendable {
    var territoryID: String
    var region: TerritoryRegion
    /// The country's own last 90 days.
    var own: SalesSignal
    /// Every country of the region added together, this one included: the
    /// pooled sample that counts toward Fairly sure for a thin country.
    var regionTotal: SalesSignal
    /// The region's prior the country was shrunk toward.
    var prior: BetaPrior
    /// The posterior mean: (own starts + α) ÷ (own page views + α + β).
    var rate: Double
    /// How much of `rate` is the country's own sample, 0–1.
    var ownWeight: Double

    /// The region carries most of the estimate.
    var leansOnRegion: Bool { ownWeight < ConversionPooling.borrowingWeight }
}
