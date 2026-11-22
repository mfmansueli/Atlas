//
//  LifecycleReport.swift
//  Atlas
//

import Foundation

/// What Apple's subscription event and state reports say beyond Sales and
/// Trends: each offer by name and how many paid afterwards, subscribers
/// Apple couldn't charge, plan changes and why people canceled.
struct LifecycleReport: Hashable, Sendable {
    struct Offer: Hashable, Sendable, Identifiable {
        var name: String
        /// Apple's Offer Type, e.g. "Free Trial", "Offer Code".
        var type: String
        var subscriptions: [String]
        var started: Int
        /// The first charge at the regular price.
        var paidAfterwards: Int
        var rate: AnalyticsRate
        /// Against the app's average for every offer.
        var standing: RateStanding?
        /// When the first people reach the regular price, for an offer too
        /// young to have a rate.
        var firstRenewal: AnalyticsDay?

        var id: String { name }

        var isTooYoung: Bool { firstRenewal != nil }
    }

    struct Count: Hashable, Sendable, Identifiable {
        var name: String
        var detail: String
        var count: Int
        var share: Double

        var id: String { name }
    }

    var period: AnalyticsPeriod
    var offers: [Offer]
    /// Every offer's paid-afterwards rate together.
    var offerAverage: Double?
    /// Subscriptions that entered billing retry or a grace period.
    var couldNotCharge: Int
    /// Paid again while Apple retried.
    var recovered: Int
    /// Canceled at the end of the 60-day retry.
    var lost: Int
    /// Voluntary and involuntary churn together.
    var cancellations: Int
    /// From the newest Subscription State day; nil without one.
    var inGracePeriod: Int?
    var inBillingRetry: Int?
    var planChanges: [Count]
    var cancelReasons: [Count]

    /// The share of cancellations that were billing failures.
    var lostShare: Double? {
        cancellations > 0 ? Double(lost) / Double(cancellations) : nil
    }

    var recoveredShare: Double? {
        couldNotCharge > 0 ? Double(recovered) / Double(couldNotCharge) : nil
    }

    /// Lost to billing, scaled to 30 days.
    var lostPerMonth: Int {
        Int((Double(lost) * 30 / Double(max(period.length, 1))).rounded())
    }
}
