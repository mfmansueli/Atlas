//
//  PriceConfidence.swift
//  Atlas
//

import Foundation

/// How sure one country's price suggestion is, and why in one line with one
/// number (README-DS §9): "Europe: 2,100 page views and 24 trials in 90 days."
struct PriceConfidence: Hashable, Sendable {
    var level: RecommendationConfidence
    var reason: String
    /// The region whose sales made it Fairly sure, for a thin country.
    var borrowedFrom: TerritoryRegion?
    /// The earlier change behind Sure.
    var effect: PriorChangeEffect?

    static func notVerySure(_ reason: String) -> PriceConfidence {
        PriceConfidence(level: .low, reason: reason)
    }

    var howSure: HowSure { level.howSure }
}
