//
//  PriceTestWindows.swift
//  Atlas
//

import Foundation

/// The 28 days before a price test and its 28 days, for the test's
/// countries and for the comparison region, kept once Apple's reports
/// cover the test's last day (`LivePricingSales`).
struct PriceTestWindows: Hashable, Codable, Sendable {
    var testBefore: SalesSignal
    var testDuring: SalesSignal
    /// Nil with No Comparison.
    var controlBefore: SalesSignal?
    var controlDuring: SalesSignal?
    var readOn: Date
}
