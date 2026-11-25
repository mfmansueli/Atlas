//
//  PriceIndexSource.swift
//  Atlas
//

import Foundation

/// A purchasing-power source a strategy can price by. Edition details (date,
/// badge, newer edition) live in `PriceIndexEdition`, inside the snapshot.
enum PriceIndexSource: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case bigMac
    case worldBank
    case imf
    case custom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bigMac: String(localized: "Big Mac Index", comment: "kind:section-title")
        case .worldBank: String(localized: "World Bank PPP price level", comment: "kind:section-title")
        case .imf: String(localized: "IMF implied PPP rate", comment: "kind:section-title")
        case .custom: String(localized: "Custom index", comment: "kind:section-title")
        }
    }

    /// For "Region median of World Bank" in the fallback chain.
    var shortName: String {
        switch self {
        case .bigMac: String(localized: "Big Mac", comment: "kind:section-title")
        case .worldBank: String(localized: "World Bank", comment: "kind:section-title")
        case .imf: String(localized: "IMF", comment: "kind:section-title")
        case .custom: String(localized: "custom index", comment: "kind:other")
        }
    }

    var publisher: String {
        switch self {
        case .bigMac: "The Economist"
        case .worldBank: String(localized: "World Bank", comment: "kind:section-title")
        case .imf: String(localized: "International Monetary Fund", comment: "kind:section-title")
        case .custom: String(localized: "Imported CSV", comment: "kind:section-title")
        }
    }

    /// The index picker's one-line description.
    var summary: String {
        switch self {
        case .bigMac:
            String(localized: """
            Raw index, not GDP-adjusted. Easy to explain; fewer countries, milder discounts. \
            The euro area is one entry shared by 21 territories.
            """, comment: "kind:description")
        case .worldBank:
            String(localized: """
            Price level ratio of PPP conversion factor to market exchange rate. Broadest coverage and deeper discounts \
            in emerging markets; runs a year or two behind.
            """, comment: "kind:description")
        case .imf:
            String(
                localized: "Implied PPP conversion rate divided by the market rate. Broad coverage, updated every April and October.",
                comment: "kind:description"
            )
        case .custom:
            String(
                localized: "A CSV of territory code → factor, or a local reference price. Unmatched codes are listed when you import.",
                comment: "kind:description"
            )
        }
    }

    var sourceURL: URL? {
        switch self {
        case .bigMac: URL(string: "https://www.economist.com/big-mac-index")
        case .worldBank: URL(string: "https://data.worldbank.org/indicator/PA.NUS.PPP")
        case .imf: URL(string: "https://www.imf.org/external/datamapper/PPPEX@WEO")
        case .custom: nil
        }
    }
}
