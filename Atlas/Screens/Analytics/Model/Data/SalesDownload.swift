//
//  SalesDownload.swift
//  Atlas
//

import Foundation

/// What one read of Sales and Trends brought: the days it settled, and
/// their facts.
struct SalesDownload: Hashable, Sendable {
    /// Days whose event and subscriber reports were read, or that Apple
    /// has nothing for.
    var days: [AnalyticsDay] = []
    var events: [SubscriptionEventFact] = []
    var subscribers: [SubscriberFact] = []
    var activeDays: [AnalyticsDay] = []
    var active: [ActiveSubscriptionsFact] = []
    /// Days whose event report failed: left unread, so the next check
    /// asks again, while the days that did load are kept.
    var failedDays: [AnalyticsDay] = []
    /// Why the first failed day failed, with Apple's code for Details.
    var failure: AppleErrorCopy?
}
