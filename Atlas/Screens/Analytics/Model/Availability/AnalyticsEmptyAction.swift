//
//  AnalyticsEmptyAction.swift
//  Atlas
//

import Foundation

/// The one button an Analytics empty state can have.
enum AnalyticsEmptyAction: Hashable, Sendable {
    /// Subscriptions with nothing to count: the prices and trials are set
    /// in Pricing.
    case openPricing
    /// A version too new for crash numbers: its card.
    case openVersion(String)

    var title: String {
        switch self {
        case .openPricing: String(localized: "Open Pricing", comment: "kind:button · Analytics empty state")
        case let .openVersion(version): String(localized: "Open Version \(version)", comment: "kind:button · Analytics empty state")
        }
    }
}
