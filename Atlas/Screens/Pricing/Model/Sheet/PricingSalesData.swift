//
//  PricingSalesData.swift
//  Atlas
//

import Foundation

/// What a product's recent sales say, per territory (alpha-3), and whether
/// Atlas could read them at all.
struct PricingSalesData: Hashable, Sendable {
    enum Availability: Hashable, Sendable {
        /// Sales and Trends were read; territories without a signal had too few.
        case available
        /// The key reads Sales and Trends, but the app has no sales there yet
        /// (Alba, Nov 2026). App Analytics page views may still be in
        /// `signals`, with zero starts.
        case noSalesYet
        /// The key's role can't read Sales and Trends or App Analytics.
        case roleCannotRead
        /// The person turned off Settings → Pricing → "Use sales data for
        /// suggestions".
        case turnedOff
        /// Atlas doesn't read sales for this source yet.
        case notRead
    }

    /// The default window, for HowSure's thresholds.
    static let windowDays = 90
    /// The short window the popover and Reason column quote.
    static let recentWindowDays = 28

    var availability: Availability
    /// Each territory's last `windowDays` (90) days.
    var signals: [String: SalesSignal] = [:]
    /// Each territory's last `recentWindowDays` (28) days.
    var recentSignals: [String: SalesSignal] = [:]
    var priorChanges: [String: PriorPriceChange] = [:]
    /// Finished price tests, for every country of their region.
    var priceTests: [String: PriceTestEvidence] = [:]
    var baseTerritoryID = "USA"
    /// The last day the reports cover (Apple's data runs a few days behind).
    var readThrough: Date?

    static let notRead = PricingSalesData(availability: .notRead)

    /// Sales were read, whether or not there are any yet.
    var canRead: Bool { availability == .available || availability == .noSalesYet }

    func pageViews(in territoryID: String) -> Int? {
        signals[territoryID]?.pageViews
    }

    func evidence(for territoryID: String) -> SalesEvidence {
        guard canRead else { return .unavailable }
        return SalesEvidence(
            canReadSales: true,
            signal: signals[territoryID],
            baseSignal: signals[baseTerritoryID],
            priorChange: priorChanges[territoryID]
        )
    }
}
