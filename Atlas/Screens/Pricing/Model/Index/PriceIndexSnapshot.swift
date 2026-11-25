//
//  PriceIndexSnapshot.swift
//  Atlas
//

import Foundation

/// The index data the app ships with (`PriceIndexSnapshot.json`), so pricing
/// works offline, plus any custom index the person imported.
///
/// `bundled()` holds the publishers' figures (World Bank, IMF, Big Mac),
/// each value with its year and method; `sample()` holds the design
/// prototype's approximate values (`isApproximate`) for DEBUG and tests.
struct PriceIndexSnapshot: Hashable, Sendable {
    /// True for illustrative values (the sample), not published ones.
    var isApproximate: Bool
    /// Where the values come from and how far to trust them.
    var note: String
    var snapshotDate: Date
    /// The territory every level is relative to (`USA`).
    var referenceTerritoryID: String
    var indices: [PriceIndexSource: PriceIndex]

    func index(_ source: PriceIndexSource) -> PriceIndex? {
        indices[source]
    }

    /// A territory's raw level in a source, relative to the reference territory.
    func level(_ source: PriceIndexSource, territoryID: String) -> Decimal? {
        indices[source]?.level(for: territoryID)
    }

    /// Territories with a value in a source, e.g. 74 for Big Mac.
    func coverage(of source: PriceIndexSource) -> Int {
        indices[source]?.coverage ?? 0
    }

    /// The snapshot with an index added or replaced, e.g. a custom import.
    func adding(_ index: PriceIndex) -> PriceIndexSnapshot {
        var copy = self
        copy.indices[index.source] = index
        return copy
    }

    /// Each region's median raw level in a source, for the "region median"
    /// fallback. With an even count it takes the upper middle value, as the
    /// prototype does. Regions without any value are left out.
    func regionMedians(of source: PriceIndexSource, catalog: TerritoryCatalog) -> [TerritoryRegion: Decimal] {
        guard let index = indices[source] else { return [:] }
        var medians: [TerritoryRegion: Decimal] = [:]
        for region in TerritoryRegion.allCases {
            let values = catalog.territories(in: region).compactMap { index.level(for: $0.id) }.sorted()
            if !values.isEmpty { medians[region] = values[values.count / 2] }
        }
        return medians
    }
}
