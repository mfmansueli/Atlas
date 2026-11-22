//
//  SubscriptionGracePeriodAttributes.swift
//  Atlas
//

import Foundation

/// A `subscriptionGracePeriods` resource: whether Billing Grace Period is
/// on for the app's subscriptions, and for how long.
struct SubscriptionGracePeriodAttributes: Decodable, Sendable {
    var optIn: Bool?
    var sandboxOptIn: Bool?
    /// `THREE_DAYS`, `SIXTEEN_DAYS` or `TWENTY_EIGHT_DAYS`.
    var duration: String?
    /// `ALL_RENEWALS` or `PAID_TO_PAID_ONLY`.
    var renewalType: String?
}
