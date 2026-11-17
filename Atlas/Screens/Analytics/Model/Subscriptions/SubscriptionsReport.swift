//
//  SubscriptionsReport.swift
//  Atlas
//

import Foundation

/// The Subscriptions view: what leads to an action in Pricing, the paywall
/// or Retention.
struct SubscriptionsReport: Hashable, Sendable {
    /// One renewal's rate for one subscription.
    struct Renewal: Hashable, Sendable, Identifiable {
        var subscription: String
        /// 1 for the first renewal, 2 for the second, 3 for the third and later.
        var index: Int
        var renewed: Int
        var due: Int
        var rate: AnalyticsRate

        var id: String { "\(subscription)|\(index)" }

        var periodTitle: String {
            switch index {
            case 1: String(localized: "1st renewal")
            case 2: String(localized: "2nd renewal")
            default: String(localized: "3rd and later")
            }
        }
    }

    struct Reason: Hashable, Sendable, Identifiable {
        var name: String
        var detail: String
        var count: Int
        var share: Double

        var id: String { name }
    }

    struct Product: Hashable, Sendable, Identifiable {
        var name: String
        var active: Int?
        var trialToPaid: AnalyticsRate
        var proceeds: Decimal

        var id: String { name }
    }

    struct TerritoryRow: Hashable, Sendable, Identifiable {
        var code: String
        var name: String
        var paid: Int
        var ended: Int
        var trialToPaid: AnalyticsRate

        var id: String { code }
    }

    var period: AnalyticsPeriod
    var active: Int?
    /// "+3%" against the snapshot one period earlier.
    var activeChange: String?
    /// Of the trials that ended in the period, the share that paid.
    var trialToPaid: AnalyticsRate
    var trialToPaidComparison: PeriodComparison?
    var trialAverage: Double?
    var proceeds: Decimal
    var proceedsChange: String?
    var refunds: Int
    var charges: Int
    var renewals: [Renewal]
    var cancellations: Int
    var reasons: [Reason]
    /// Cancellations before the first renewal was paid.
    var earlyCancellations: Int
    var products: [Product]
    var territories: [TerritoryRow]

    /// The share of cancellations that came before the first renewal.
    var earlyShare: AnalyticsRate {
        AnalyticsStatistics.rate(count: earlyCancellations, total: cancellations)
    }
}
