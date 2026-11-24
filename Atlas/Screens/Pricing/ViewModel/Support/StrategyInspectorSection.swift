//
//  StrategyInspectorSection.swift
//  Atlas
//

import Foundation

/// The collapsible sections of the Strategy tab, in order.
enum StrategyInspectorSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case method
    case priceIndex
    case fallback
    case regionalTiers
    case limits
    case tiers
    case excluded
    case rounding
    case formula
    case indexData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .method: String(localized: "Method")
        case .priceIndex: String(localized: "Price index")
        case .fallback: String(localized: "Fallback chain")
        case .regionalTiers: String(localized: "Regional tiers")
        case .limits: String(localized: "Intensity and limits")
        case .tiers: String(localized: "Tiers")
        case .excluded: String(localized: "Excluded from the index")
        case .rounding: String(localized: "Rounding")
        case .formula: String(localized: "Formula")
        case .indexData: String(localized: "Index data")
        }
    }
}
