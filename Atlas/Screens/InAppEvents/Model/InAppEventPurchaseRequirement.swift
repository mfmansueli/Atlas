//
//  InAppEventPurchaseRequirement.swift
//  Atlas
//

import Foundation

/// Whether taking part in an In-App Event needs an in-app purchase; the
/// event's details page says so. In a subscription app only an extra cost
/// for the event counts, e.g. a pay-per-view on top of the subscription.
/// The values are App Store Connect's (`AppEvent.Attributes`).
enum InAppEventPurchaseRequirement: String, CaseIterable, Identifiable, Hashable, Sendable {
    case noCostAssociated = "NO_COST_ASSOCIATED"
    case inAppPurchase = "IN_APP_PURCHASE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noCostAssociated: String(localized: "No purchase needed")
        case .inAppPurchase: String(localized: "Needs an In-App Purchase")
        }
    }
}
