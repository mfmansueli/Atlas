//
//  PriceIndexSnapshot+Loading.swift
//  Atlas
//

import Foundation

extension PriceIndexSnapshot {
    /// `PriceIndexSnapshot.json` in `Screens/Pricing/Resources`: the
    /// publishers' figures, written by `scripts/price-index/fetch_price_index.py`
    /// before each release.
    static let resourceName = "PriceIndexSnapshot"
    /// `PriceIndexSnapshot-Sample.json`: the design prototype's approximate
    /// values, for DEBUG scenes, previews and the tests that check the
    /// design's numbers. Never used by live pricing.
    static let sampleResourceName = "PriceIndexSnapshot-Sample"

    enum LoadingError: Error, Equatable {
        case missingResource
    }

    /// No index data at all: every territory falls back to equalized.
    static let empty = PriceIndexSnapshot(
        isApproximate: true,
        note: "",
        snapshotDate: .distantPast,
        referenceTerritoryID: "USA",
        indices: [:]
    )

    /// The published snapshot bundled with the app.
    static func bundled(in bundle: Bundle = .main) throws -> PriceIndexSnapshot {
        try resource(resourceName, in: bundle)
    }

    /// The prototype's sample snapshot (approximate).
    static func sample(in bundle: Bundle = .main) throws -> PriceIndexSnapshot {
        try resource(sampleResourceName, in: bundle)
    }

    private static func resource(_ name: String, in bundle: Bundle) throws -> PriceIndexSnapshot {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw LoadingError.missingResource
        }
        return try PriceIndexSnapshot(jsonData: Data(contentsOf: url))
    }

    /// Decodes `PriceIndexSnapshot.json`: schema 2's `levels` (each with its
    /// year and method) or the sample's plain `factors`. Values are read
    /// through their shortest decimal form, so 0.85 stays exactly 0.85.
    init(jsonData: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: jsonData)
        var indices: [PriceIndexSource: PriceIndex] = [:]
        for (key, entry) in file.sources {
            guard let source = PriceIndexSource(rawValue: key) else { continue }
            var levels = (entry.factors ?? [:]).mapValues { Decimal(exactly: $0) }
            var provenance: [String: PriceLevelProvenance] = [:]
            for (territoryID, value) in entry.levels ?? [:] {
                levels[territoryID] = Decimal(exactly: value.level)
                provenance[territoryID] = PriceLevelProvenance(year: value.year, method: value.method ?? .exact)
            }
            for shared in entry.shared ?? [] {
                guard let value = shared.level ?? shared.factor else { continue }
                for territoryID in shared.territories {
                    levels[territoryID] = Decimal(exactly: value)
                    if shared.year != nil || shared.method != nil {
                        provenance[territoryID] = PriceLevelProvenance(year: shared.year, method: shared.method ?? .exact)
                    }
                }
            }
            let edition = PriceIndexEditionText.localized(entry.edition, source: key)
            indices[source] = PriceIndex(source: source, edition: edition, levels: levels, provenance: provenance)
        }
        try self.init(
            isApproximate: file.approximate,
            note: file.note,
            snapshotDate: PriceIndexEdition.parseDay(file.snapshotDate),
            referenceTerritoryID: file.referenceTerritory,
            indices: indices
        )
    }

    private struct File: Decodable {
        var approximate: Bool
        var note: String
        var snapshotDate: String
        var referenceTerritory: String
        var sources: [String: Source]
    }

    private struct Source: Decodable {
        var edition: PriceIndexEdition
        /// The sample's plain values.
        var factors: [String: Double]?
        /// Schema 2: each value with its year and method.
        var levels: [String: Level]?
        /// One value shared by several territories, e.g. the Big Mac Index's
        /// single euro-area entry.
        var shared: [SharedEntry]?
    }

    private struct Level: Decodable {
        var level: Double
        var year: Int?
        var method: PriceLevelMethod?
    }

    private struct SharedEntry: Decodable {
        var name: String
        /// Schema 2.
        var level: Double?
        /// The sample.
        var factor: Double?
        var year: Int?
        var method: PriceLevelMethod?
        var territories: [String]
    }
}
