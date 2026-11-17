//
//  AnalyticsDataset.swift
//  Atlas
//

import Foundation

/// Everything Analytics knows about one app: its facts, and what's missing
/// and why. Every view is computed from it.
struct AnalyticsDataset: Hashable, Sendable {
    var appID: StoreApp.ID
    var appName: String
    var engagement: [EngagementFact] = []
    var pages: [EngagementFact] = []
    var events: [SubscriptionEventFact] = []
    var subscribers: [SubscriberFact] = []
    var active: [ActiveSubscriptionsFact] = []
    var engagementState: EngagementState = .ready
    var salesState: SalesState = .ready
    /// Whether the app sells a subscription; without one the funnel ends
    /// at downloads.
    var sellsSubscriptions = true

    /// The newest day of store-page data, else of sales.
    var through: AnalyticsDay? {
        engagement.map(\.day).max() ?? events.map(\.day).max()
    }

    var firstDay: AnalyticsDay? {
        engagement.map(\.day).min() ?? events.map(\.day).min()
    }

    /// Days of data so far, for an app that has less than a period.
    var dayCount: Int {
        guard let first = firstDay, let last = through else { return 0 }
        return last.number - first.number + 1
    }

    var hasEngagement: Bool { engagementState == .ready && !engagement.isEmpty }
    var hasSales: Bool { salesState == .ready && sellsSubscriptions }
}
