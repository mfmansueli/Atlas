//
//  RecommendationConfidence.swift
//  Atlas
//

import Foundation

/// The three-bar confidence badge. Neutral in color: it says what a
/// suggestion is based on, not whether it's good.
enum RecommendationConfidence: Int, CaseIterable, Comparable, Hashable, Sendable {
    /// Not very sure: purchasing power only, an index value that isn't
    /// real published data, or a simulated price grid.
    case low = 1
    /// Fairly sure: a real index and grid, and enough of the app's sales in
    /// the territory or its pooled region (`PriceConfidenceRule`).
    case medium
    /// Sure: an earlier price change there with a clear effect.
    case high

    /// How many of the three bars are filled.
    var bars: Int { rawValue }

    var title: String {
        switch self {
        case .low: String(localized: "Low confidence", comment: "kind:section-title")
        case .medium: String(localized: "Medium confidence", comment: "kind:section-title")
        case .high: String(localized: "High confidence", comment: "kind:section-title")
        }
    }

    /// The suggestion popover's note.
    var note: String {
        switch self {
        case .low: String(localized: "Purchasing power only; too few sales here to say more.", comment: "kind:hint")
        case .medium: String(localized: "Based on your sales, not a price test. Results show how many more starts.", comment: "kind:hint")
        case .high: String(localized: "Backed by an earlier price change in this territory.", comment: "kind:hint")
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
