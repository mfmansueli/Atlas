//
//  PricingMethod.swift
//  Atlas
//

import Foundation

/// How a strategy turns Apple's equalized price into a proposed one.
enum PricingMethod: String, CaseIterable, Codable, Hashable, Sendable {
    /// World Bank PPP at full intensity, 30% floor, discounts only.
    case recommended
    /// Apple's equalized price as is: currency and tax conversion only.
    case equalized
    /// A chosen price index with the inspector's settings.
    case priceIndex
    /// One multiplier per region.
    case regionalTiers

    var title: String {
        switch self {
        case .recommended: String(localized: "Suggested", comment: "kind:section-title")
        case .equalized: String(localized: "Apple equalization", comment: "kind:section-title")
        case .priceIndex: String(localized: "Price index", comment: "kind:section-title")
        case .regionalTiers: String(localized: "Custom regional tiers", comment: "kind:section-title")
        }
    }

    var summary: String {
        switch self {
        case .recommended:
            String(
                localized: "World Bank PPP at full intensity, 30% floor, discounts only. Your sales adjust confidence and step size.",
                comment: "kind:description"
            )
        case .equalized: String(localized: "Currency and tax conversion only.", comment: "kind:description")
        case .priceIndex: String(localized: "Choose a source and tune it below.", comment: "kind:description")
        case .regionalTiers: String(localized: "One multiplier per region.", comment: "kind:description")
        }
    }
}
