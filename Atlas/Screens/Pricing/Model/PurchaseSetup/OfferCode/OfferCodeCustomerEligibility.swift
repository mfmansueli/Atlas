//
//  OfferCodeCustomerEligibility.swift
//  Atlas
//

import Foundation

/// Who can redeem an offer code: App Store Connect's
/// `SubscriptionCustomerEligibility`.
enum OfferCodeCustomerEligibility: String, CaseIterable, Hashable, Sendable {
    /// Never subscribed.
    case new = "NEW"
    /// Subscribed now.
    case existing = "EXISTING"
    /// Subscribed before.
    case expired = "EXPIRED"

    var title: String {
        switch self {
        case .new: String(localized: "New subscribers")
        case .existing: String(localized: "Active subscribers")
        case .expired: String(localized: "Expired subscribers")
        }
    }

    /// The eligibilities in App Store Connect's order.
    static func sorted(_ eligibilities: some Sequence<Self>) -> [Self] {
        let set = Set(eligibilities)
        return allCases.filter(set.contains)
    }

    /// "New and expired subscribers".
    static func title(of eligibilities: [Self]) -> String {
        guard !eligibilities.isEmpty else { return String(localized: "Nobody") }
        return eligibilities.map(\.title).formatted(.list(type: .and))
    }
}
