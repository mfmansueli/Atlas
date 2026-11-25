//
//  PriceIndex.swift
//  Atlas
//

import Foundation

/// One source's price levels for the territories it covers.
struct PriceIndex: Hashable, Sendable {
    var source: PriceIndexSource
    var edition: PriceIndexEdition
    /// Price level per territory (alpha-3 ID), relative to the snapshot's
    /// reference territory (the United States = 1.0). Missing = no data.
    var levels: [String: Decimal]
    /// For a custom index, the imported file's name, shown as its publisher.
    var fileName: String?
    /// Each value's year and method, by territory. A value without an entry
    /// (the sample snapshot, a custom CSV) is exact, of the edition's year.
    var provenance: [String: PriceLevelProvenance] = [:]

    var publisher: String { fileName ?? source.publisher }

    /// How many territories have a value.
    var coverage: Int { levels.count }

    /// How many values are fallbacks: an older year or another series.
    var fallbackCount: Int {
        levels.keys.count { levelProvenance(for: $0)?.isFallback == true }
    }

    func level(for territoryID: String) -> Decimal? {
        levels[territoryID]
    }

    /// The value's year and method; nil when the territory has no value.
    func levelProvenance(for territoryID: String) -> PriceLevelProvenance? {
        guard levels[territoryID] != nil else { return nil }
        return provenance[territoryID] ?? PriceLevelProvenance(year: edition.dataYear, method: .exact)
    }

    /// "74 of 175 territories".
    func coverageLabel(of total: Int) -> String {
        String(localized: "\(coverage) of \(total) territories", comment: "kind:other")
    }
}
