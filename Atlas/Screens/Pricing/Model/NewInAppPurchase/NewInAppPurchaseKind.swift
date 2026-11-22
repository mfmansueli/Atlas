//
//  NewInAppPurchaseKind.swift
//  Atlas
//

import Foundation

/// The kinds of in-app purchase Create In-App Purchase makes, with App
/// Store Connect's `InAppPurchaseType`.
enum NewInAppPurchaseKind: String, CaseIterable, Hashable, Sendable {
    /// Bought once and kept, e.g. a lifetime unlock.
    case nonConsumable = "NON_CONSUMABLE"
    /// Used up and bought again, e.g. coins.
    case consumable = "CONSUMABLE"
    /// Access for a set time that doesn't renew by itself.
    case nonRenewingSubscription = "NON_RENEWING_SUBSCRIPTION"

    var title: String {
        switch self {
        case .nonConsumable: String(localized: "Non-consumable")
        case .consumable: String(localized: "Consumable")
        case .nonRenewingSubscription: String(localized: "Non-renewing subscription")
        }
    }

    /// Family Sharing is offered for non-consumables only (and
    /// auto-renewable subscriptions, which Create Subscription makes).
    var supportsFamilySharing: Bool {
        self == .nonConsumable
    }
}
