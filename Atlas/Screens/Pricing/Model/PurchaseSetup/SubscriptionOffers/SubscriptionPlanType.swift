//
//  SubscriptionPlanType.swift
//  Atlas
//

import Foundation

/// The payment plan of a subscription an offer is for: App Store Connect's
/// `targetSubscriptionPlanType` (`SubscriptionPlanType` in its API: paid
/// up front, `UPFRONT`, or a plan paid monthly, `MONTHLY`, for a
/// subscription sold with one). Left out (nil), the offer is for every
/// plan. App Store Connect takes it when the offer is created and doesn't
/// let it change.
enum SubscriptionPlanType: String, CaseIterable, Hashable, Sendable {
    case upfront = "UPFRONT"
    case monthly = "MONTHLY"

    var title: String {
        switch self {
        case .upfront: String(localized: "Paid up front")
        case .monthly: String(localized: "Paid monthly")
        }
    }

    /// "Every plan" for nil.
    static func title(of plan: SubscriptionPlanType?) -> String {
        plan?.title ?? String(localized: "Every plan")
    }

    /// The attribute's value in a resource's or a create's attributes.
    static let attribute = "targetSubscriptionPlanType"

    /// The plan an offer's attributes name; nil when they name none.
    init?(attributes: [String: Any]) {
        guard let value = (attributes[Self.attribute] as? String).flatMap(Self.init(rawValue:)) else { return nil }
        self = value
    }
}
