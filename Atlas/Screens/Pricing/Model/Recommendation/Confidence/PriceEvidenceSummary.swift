//
//  PriceEvidenceSummary.swift
//  Atlas
//

import Foundation

/// The sales behind one country's suggestion, for the how-sure tip in the
/// popover and the Reason column (no new line or pill, board 73):
/// "Brazil · 28 days: 1,240 page views, 31 trials, 12 paid" and, for a thin
/// country, "Uses Europe’s sales" ("Too few sales here, so Atlas uses
/// Europe’s." in the tip, board 76).
struct PriceEvidenceSummary: Hashable, Sendable {
    var territoryName: String
    /// The country's last 28 days.
    var recent: SalesSignal?
    /// The region whose sales a thin country uses to be Fairly sure (the
    /// MCP's `borrowedFrom`).
    var borrowedFrom: TerritoryRegion?
    /// The region's page views in 90 days, all its countries together.
    var regionPageViews = 0
    /// The product counts trial starts (else every start).
    var usesTrials = true

    /// Nothing to say: no recent page views and no region's sales used.
    var isEmpty: Bool { recentLine == nil && borrowedLine == nil }

    /// The popover's how-sure tip lines.
    var tip: String {
        [recentLine.map { "\(territoryName) · \($0)" }, borrowedTip].compactMap(\.self).joined(separator: "\n")
    }

    /// The Reason column's part: the region's sales it uses, else the 28 days.
    var short: String? {
        borrowedLine ?? recentLine
    }

    /// "28 days: 1,240 page views, 31 trials, 12 paid".
    var recentLine: String? {
        guard let recent, recent.pageViews > 0 else { return nil }
        let views = PriceConfidenceText.pageViews(recent.pageViews)
        let starts = PriceConfidenceText.starts(usesTrials ? recent.trialStarts : recent.starts, trials: usesTrials)
        guard usesTrials else {
            return String(localized: "28 days: \(views), \(starts)", comment: "kind:other")
        }
        let paid = PricingText.grouped(recent.paidStarts)
        return String(localized: "28 days: \(views), \(starts), \(paid) paid", comment: "kind:other")
    }

    /// "Uses Europe’s sales".
    var borrowedLine: String? {
        borrowedFrom.map(PooledSalesText.short)
    }

    /// "Too few sales here, so Atlas uses Europe’s."
    var borrowedTip: String? {
        borrowedFrom.map(PooledSalesText.tip)
    }
}
