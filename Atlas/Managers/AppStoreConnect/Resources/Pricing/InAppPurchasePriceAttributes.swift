//
//  InAppPurchasePriceAttributes.swift
//  Atlas
//

import Foundation

/// The fields Atlas reads from an `inAppPurchasePrices` resource: one of an
/// in-app purchase's manual prices (set by the person, the base territory's
/// among them) or automatic ones (Apple's equalized prices elsewhere). It's
/// in effect from `startDate` (none: from the start) until `endDate` (none:
/// until further notice).
struct InAppPurchasePriceAttributes: Decodable, Sendable {
    var startDate: String?
    var endDate: String?
    var manual: Bool?
}
