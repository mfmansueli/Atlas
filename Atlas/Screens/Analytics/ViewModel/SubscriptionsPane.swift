//
//  SubscriptionsPane.swift
//  Atlas
//

import Foundation

/// The views inside Analytics → Subscriptions.
enum SubscriptionsPane: String, Hashable, Sendable, CaseIterable, Identifiable {
    case summary
    /// What happens at the cancel screen (Retention Messaging).
    case retention
    case offers
    case billing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: String(localized: "Summary")
        case .retention: String(localized: "Retention")
        case .offers: String(localized: "Offers")
        case .billing: String(localized: "Billing and Plans")
        }
    }
}
