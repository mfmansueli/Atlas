//
//  ActiveSubscriptionsFact.swift
//  Atlas
//

import Foundation

/// How many subscriptions were active on one day, from Sales and Trends'
/// Subscription report.
struct ActiveSubscriptionsFact: Hashable, Sendable, Codable {
    var day: AnalyticsDay
    var appID: String
    var subscription: String
    var territory: String
    /// Paying at the standard price or a paid offer.
    var paid = 0
    /// In a free trial.
    var trials = 0

    private enum CodingKeys: String, CodingKey {
        case day = "d", appID = "a", subscription = "s", territory = "t", paid = "p", trials = "f"
    }
}
