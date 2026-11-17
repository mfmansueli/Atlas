//
//  InAppPurchaseAttributes.swift
//  Atlas
//

import Foundation

/// The fields Atlas reads from an `inAppPurchases` (v2) resource.
struct InAppPurchaseAttributes: Decodable, Sendable {
    var name: String
    var productId: String
    var inAppPurchaseType: String?
    var state: String?
}
