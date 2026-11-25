//
//  PricingSalesInput.swift
//  Atlas
//

import Foundation

/// What `AnalyticsStore` already holds for one app, as Pricing reads it.
/// There is no second download: Analytics' refresh fills the store, and
/// Pricing only reads it.
struct PricingSalesInput: Hashable, Sendable {
    /// The app's Standard App Analytics facts, by territory, source and
    /// device. Page views and first downloads are the app's: App Analytics
    /// doesn't split them by subscription, so every product of the app
    /// shares them.
    var engagement: [EngagementFact] = []
    /// The app's Sales and Trends subscription events, every product's.
    var events: [SubscriptionEventFact] = []
    /// The app's charges and proceeds (in US dollars), every product's.
    var subscribers: [SubscriberFact] = []
    /// The app's active subscriptions on the days the Subscription report
    /// was read.
    var active: [ActiveSubscriptionsFact] = []
    /// Days of Sales and Trends read (day numbers). A day Apple has no
    /// report for answers 404 and still counts as read, with no lines.
    var salesDays: Set<Int> = []
    var salesState = SalesState.needsVendorNumber
    /// Settings → Pricing → "Use sales data for suggestions".
    var usesSalesData = true
}
