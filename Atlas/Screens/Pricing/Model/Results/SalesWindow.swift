//
//  SalesWindow.swift
//  Atlas
//

import Foundation

/// One territory's 28 days on one side of a price change.
struct SalesWindow: Hashable, Sendable {
    var pageViews: Int
    var starts: Int
    /// After commission and tax, in US dollars.
    var proceeds: Decimal
    /// The days Apple's reports cover on this side: under 28 is too few to
    /// tell (`ResultsEvaluator`).
    var days = ResultsEvaluator.windowDays

    /// Page view → start conversion, or nil without views.
    var conversion: Double? {
        pageViews > 0 ? Double(starts) / Double(pageViews) : nil
    }

    /// "1.38%", or "—" without views.
    var conversionText: String {
        conversion.map { PricingText.percent($0) } ?? "—"
    }
}

extension SalesWindow {
    /// A window from a territory's signal over the same days.
    init(signal: SalesSignal, days: Int = ResultsEvaluator.windowDays) {
        self.init(pageViews: signal.pageViews, starts: signal.starts, proceeds: signal.proceeds, days: days)
    }
}
