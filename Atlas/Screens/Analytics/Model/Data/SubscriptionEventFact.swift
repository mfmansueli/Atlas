//
//  SubscriptionEventFact.swift
//  Atlas
//

import Foundation

/// One line of Sales and Trends' Subscription Event report, kept to what
/// Analytics reads.
struct SubscriptionEventFact: Hashable, Sendable, Codable {
    var day: AnalyticsDay
    var appID: String
    var kind: SubscriptionEventKind
    /// The subscription's name, e.g. "Lumen Plus Annual".
    var subscription: String
    /// ISO alpha-2.
    var territory: String
    /// "iPhone", "iPad", "Desktop"…
    var device: String = ""
    /// "Free Trial", "Pay Up Front", "Pay As You Go" or "".
    var offerType: String = ""
    /// Paid periods in a row so far; 1 after the first renewal's payment.
    var paidPeriods = 0
    /// Days from the last charge to turning renewal off, when Apple says.
    var daysBeforeCanceling: Int?
    /// Apple's reason, on cancellations: "Canceled", "Billing Issue", …
    var reason: String = ""
    var quantity = 1

    private enum CodingKeys: String, CodingKey {
        case day = "d", appID = "a", kind = "k", subscription = "s", territory = "t", offerType = "o"
        case paidPeriods = "p", daysBeforeCanceling = "c", reason = "r", quantity = "q", device = "v"
    }
}
