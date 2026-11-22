//
//  SubscriberCounts.swift
//  Atlas
//

import Foundation

/// Trials and paid subscribers for one slice (a product page, a campaign,
/// a source), from Apple's subscription event report, which names where
/// each subscriber downloaded the app from.
struct SubscriberCounts: Hashable, Sendable {
    var trials = 0
    /// Paid starts, directly or after an offer.
    var paid = 0
    /// Free trials that became paid, and those that lapsed: trials that
    /// ended in the period.
    var trialConverted = 0
    var trialLapsed = 0

    var trialsEnded: Int { trialConverted + trialLapsed }

    /// Of the trials that ended, the share that paid: the same measure as
    /// Subscriptions' trial → paid.
    func trialToPaid(average: Double? = nil) -> AnalyticsRate {
        AnalyticsStatistics.rate(count: trialConverted, total: trialsEnded, average: average)
    }

    var trialToPaidFraction: Double? {
        trialsEnded > 0 ? Double(trialConverted) / Double(trialsEnded) : nil
    }
}
