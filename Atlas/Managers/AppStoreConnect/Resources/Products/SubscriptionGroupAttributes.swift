//
//  SubscriptionGroupAttributes.swift
//  Atlas
//

import Foundation

/// The fields Atlas reads from a `subscriptionGroups` resource.
struct SubscriptionGroupAttributes: Decodable, Sendable {
    var referenceName: String
}
