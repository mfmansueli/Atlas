//
//  MeasuredRate.swift
//  Atlas
//

import Foundation

/// A rate with enough behind it to show as a percentage: its 90% range
/// (Wilson interval), how it stands against an average, and how sure it is.
struct MeasuredRate: Hashable, Sendable {
    var count: Int
    var total: Int
    /// `count ÷ total`, 0…1.
    var value: Double
    var low: Double
    var high: Double
    /// nil when there was no average to compare with.
    var standing: RateStanding?
    /// The confidence meter's filled bars, 1…3: three when the range is
    /// within ±12% of the rate, two within ±30%, one otherwise.
    var bars: Int

    /// "Sure", "Fairly sure" or "Rough".
    var sureness: String {
        switch bars {
        case 3: String(localized: "Sure")
        case 2: String(localized: "Fairly sure")
        default: String(localized: "Rough")
        }
    }
}
