//
//  SubscriptionEventKind.swift
//  Atlas
//

import Foundation

/// What Analytics makes of Sales and Trends' subscription events. Apple
/// has about 180 event names; they're sorted by what they say.
enum SubscriptionEventKind: String, Hashable, Sendable, Codable {
    /// A free trial or other introductory offer began.
    case trialStart
    /// An introductory offer became a paid subscription.
    case paidFromTrial
    /// Subscribed at the standard price without a trial.
    case paidStart
    case renewal
    case cancellation
    case refund
    case billingRetry
    case reactivation
    case other

    /// Sorts one of Apple's event names, e.g. "Paid Subscription from
    /// Introductory Offer" (older reports say "…Introductory Price").
    init(event: String) {
        let name = event.lowercased()
        if name.hasPrefix("refund") {
            self = .refund
        } else if name.hasPrefix("cancel") {
            self = .cancellation
        } else if name.hasPrefix("billing retry") {
            self = .billingRetry
        } else if name.hasPrefix("reactivat") {
            self = .reactivation
        } else if name.hasPrefix("start introductory") {
            self = .trialStart
        } else if name.contains("from introductory"), !name.hasPrefix("renewal") {
            self = .paidFromTrial
        } else if name == "subscribe" {
            self = .paidStart
        } else if name == "renew" || name.hasPrefix("renewal from") || name == "upgrade" || name == "downgrade" || name == "crossgrade" {
            self = .renewal
        } else {
            self = .other
        }
    }
}
