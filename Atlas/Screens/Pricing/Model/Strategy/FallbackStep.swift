//
//  FallbackStep.swift
//  Atlas
//

import Foundation

/// One link in the fallback chain that fills territories the chosen index
/// doesn't cover, e.g. Big Mac → World Bank → region median → equalized.
enum FallbackStep: Hashable, Sendable, Codable {
    case index(PriceIndexSource)
    /// The chosen index's median in the territory's region.
    case regionMedian
    /// Apple's equalized price (factor 1). Always the last resort.
    case equalized

    /// The chain row's title, given the chosen index.
    func title(chosen: PriceIndexSource) -> String {
        switch self {
        case let .index(source): source.name
        case .regionMedian: String(localized: "Region median of \(chosen.shortName)", comment: "kind:section-title")
        case .equalized: String(localized: "Apple’s equalized price", comment: "kind:section-title")
        }
    }
}
