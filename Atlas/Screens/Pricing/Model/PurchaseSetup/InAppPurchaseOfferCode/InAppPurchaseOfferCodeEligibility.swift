//
//  InAppPurchaseOfferCodeEligibility.swift
//  Atlas
//

import Foundation

/// Who can redeem an in-app purchase's offer code: App Store Connect's
/// `customerEligibilities` for `inAppPurchaseOfferCodes`, by how people
/// have spent in the app (not by subscription, as a subscription's are).
enum InAppPurchaseOfferCodeEligibility: String, CaseIterable, Hashable, Sendable {
    /// Never bought anything in the app.
    case nonSpender = "NON_SPENDER"
    /// Buys in the app now.
    case activeSpender = "ACTIVE_SPENDER"
    /// Bought in the app before and stopped.
    case churnedSpender = "CHURNED_SPENDER"

    var title: String {
        switch self {
        case .nonSpender: String(localized: "People who never bought")
        case .activeSpender: String(localized: "People who buy now")
        case .churnedSpender: String(localized: "People who stopped buying")
        }
    }

    /// The eligibilities in App Store Connect's order.
    static func sorted(_ eligibilities: some Sequence<Self>) -> [Self] {
        let set = Set(eligibilities)
        return allCases.filter(set.contains)
    }

    /// "People who never bought and people who stopped buying".
    static func title(of eligibilities: [Self]) -> String {
        guard !eligibilities.isEmpty else { return String(localized: "Nobody") }
        return sorted(eligibilities).map(\.title).formatted(.list(type: .and))
    }
}
