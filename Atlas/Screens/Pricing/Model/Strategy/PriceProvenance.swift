//
//  PriceProvenance.swift
//  Atlas
//

import Foundation

/// Where a territory's factor came from: the provenance badge in each row
/// (filled for the chosen index, outlined when a fallback filled the gap).
struct PriceProvenance: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case index(PriceIndexSource)
        /// The chosen index's median in the territory's region.
        case regionMedian(PriceIndexSource)
        /// No data anywhere in the chain (or Apple equalization chosen).
        case equalized
        case regionalTier(TerritoryRegion)
        case excluded
    }

    var kind: Kind
    /// True when something other than the chosen index's exact figure
    /// filled the factor: another source, a region median, or a fallback
    /// value (an older year or another series).
    var isFallback: Bool
    /// The index edition, for `.index`.
    var edition: PriceIndexEdition?
    /// The value's year and method, for `.index`.
    var level: PriceLevelProvenance?

    /// The row badge: "Big Mac Jan 26", "WB 2024", "Region median",
    /// "Equalized", "Region tier", "Excluded".
    var badge: String {
        switch kind {
        case let .index(source): edition?.badge ?? source.name
        case .regionMedian: String(localized: "Region median", comment: "kind:pill")
        case .equalized: String(localized: "Equalized", comment: "kind:pill")
        case .regionalTier: String(localized: "Region tier", comment: "kind:pill")
        case .excluded: String(localized: "Excluded", comment: "kind:pill")
        }
    }

    /// The source as breakdown lines and the Source column name it:
    /// "World Bank 2025" (or the value's own year when older, "World Bank
    /// 2024"), "region median", "no data, equalized".
    var label: String {
        switch kind {
        case let .index(source):
            if let year = level?.year, let dataYear = edition?.dataYear, year != dataYear {
                String(localized: "\(source.shortName) \(String(year))", comment: "kind:pill")
            } else {
                edition?.provenanceLabel ?? source.name
            }
        case .regionMedian: String(localized: "region median", comment: "kind:other")
        case .equalized: String(localized: "no data, equalized", comment: "kind:other")
        case .regionalTier: String(localized: "regional tier", comment: "kind:other")
        case .excluded: String(localized: "excluded", comment: "kind:other")
        }
    }

    /// The Source column's help: its text (`PriceSourceText`), and why a
    /// fallback value stands in, e.g. "World Bank · 2024 · Its newest
    /// figure for this country".
    var detail: String {
        let text = PriceSourceText.text(self)
        guard let level, level.isFallback else { return text }
        let reason = if let year = level.year, let dataYear = edition?.dataYear, year != dataYear {
            String(localized: "Its newest figure for this country", comment: "kind:hint")
        } else {
            String(localized: "Worked out from GDP figures", comment: "kind:hint")
        }
        return "\(text) · \(reason)"
    }

    /// The index behind the factor, if any.
    var source: PriceIndexSource? {
        switch kind {
        case let .index(source), let .regionMedian(source): source
        default: nil
        }
    }
}
