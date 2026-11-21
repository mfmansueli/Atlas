//
//  SubscriptionAttributes.swift
//  Atlas
//

import Foundation

/// The fields Atlas reads from a `subscriptions` resource.
struct SubscriptionAttributes: Decodable, Sendable {
    var name: String
    var productId: String
    var state: String?
    var subscriptionPeriod: String?
    /// Review Information › Review Notes: for App Review only, one per
    /// product (not localized).
    var reviewNote: String?
}
