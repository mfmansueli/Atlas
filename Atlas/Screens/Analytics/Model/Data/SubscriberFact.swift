//
//  SubscriberFact.swift
//  Atlas
//

import Foundation

/// One day's charges of one subscription in one territory, from Sales and
/// Trends' Subscriber report: what was paid, and what was refunded.
struct SubscriberFact: Hashable, Sendable, Codable {
    var day: AnalyticsDay
    var appID: String
    var subscription: String
    var territory: String
    var device: String = ""
    /// Charges that weren't refunds.
    var charges = 0
    var refunds = 0
    /// After Apple's commission and taxes, in US dollars; refunds taken off.
    var proceeds: Decimal = 0
    /// The subscription's Apple ID, from "Subscription Apple ID"; nil in
    /// facts read before Atlas kept it.
    var subscriptionID: String?

    private enum CodingKeys: String, CodingKey {
        case day = "d", appID = "a", subscription = "s", territory = "t", charges = "c", refunds = "r", proceeds = "p", device = "v"
        case subscriptionID = "i"
    }
}
