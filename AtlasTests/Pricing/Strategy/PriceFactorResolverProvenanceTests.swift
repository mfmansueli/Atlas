//
//  PriceFactorResolverProvenanceTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The fallback chain on published-style data, where each value carries its
/// year and method: exact → fallback value → next index → region median.
@Suite("PriceFactorResolver: value provenance")
struct PriceFactorResolverProvenanceTests {
    private func money(_ text: String) -> Decimal {
        PricingFixtures.money(text)
    }

    private func edition(_ source: PriceIndexSource, year: Int) -> PriceIndexEdition {
        let label = source == .worldBank ? "World Bank \(year)" : "IMF, Oct 2026"
        return PriceIndexEdition(
            label: label, badge: label, provenanceLabel: label, date: PricingSampleData.date("2026-11-11"), newerEdition: nil, dataYear: year
        )
    }

    /// World Bank: Brazil exact (2025), Bulgaria from 2024 (fallback).
    /// IMF: Taiwan only. Mexico only in neither, Canada nowhere either.
    private var resolver: PriceFactorResolver {
        let worldBank = PriceIndex(
            source: .worldBank,
            edition: edition(.worldBank, year: 2025),
            levels: ["USA": 1, "BRA": money("0.46"), "BGR": money("0.42"), "MEX": money("0.6"), "DEU": money("0.8")],
            provenance: [
                "USA": PriceLevelProvenance(year: 2025, method: .exact),
                "BRA": PriceLevelProvenance(year: 2025, method: .exact),
                "BGR": PriceLevelProvenance(year: 2024, method: .fallback),
            ]
        )
        let imf = PriceIndex(
            source: .imf,
            edition: edition(.imf, year: 2025),
            levels: ["USA": 1, "TWN": money("0.44")],
            provenance: ["TWN": PriceLevelProvenance(year: 2025, method: .fallback)]
        )
        let snapshot = PriceIndexSnapshot(
            isApproximate: false, note: "", snapshotDate: PricingSampleData.date("2026-11-25"),
            referenceTerritoryID: "USA", indices: [.worldBank: worldBank, .imf: imf]
        )
        return PriceFactorResolver(snapshot: snapshot, catalog: PricingFixtures.catalog)
    }

    private var strategy: PricingStrategy {
        var strategy = PricingStrategy.recommended
        strategy.method = .priceIndex
        strategy.indexSource = .worldBank
        strategy.fallback = [.index(.imf), .regionMedian, .equalized]
        return strategy
    }

    private func resolve(_ code: String) throws -> ResolvedFactor {
        try resolver.resolve(PricingFixtures.territory(code), strategy: strategy)
    }

    @Test @MainActor func anExactValueIsNoFallback() throws {
        let brazil = try resolve("BR")
        #expect(brazil.factor == money("0.46"))
        #expect(!brazil.provenance.isFallback)
        #expect(brazil.provenance.level == PriceLevelProvenance(year: 2025, method: .exact))
        #expect(brazil.provenance.label == "World Bank 2025")
        #expect(brazil.provenance.detail == "World Bank · 2025")
        #expect(CountryProvenanceCell.name(brazil.provenance) == "World Bank · 2025")
    }

    @Test @MainActor func anOlderYearIsAFallbackNamedByItsYear() throws {
        let bulgaria = try resolve("BG")
        #expect(bulgaria.factor == money("0.42"))
        #expect(bulgaria.provenance.kind == .index(.worldBank))
        #expect(bulgaria.provenance.isFallback)
        #expect(bulgaria.provenance.label == "World Bank 2024")
        #expect(bulgaria.provenance.detail == "World Bank · 2024 · Its newest figure for this country")
        #expect(CountryProvenanceCell.name(bulgaria.provenance) == "World Bank · 2024")
    }

    @Test func aValueWithoutItsOwnProvenanceIsExact() throws {
        let germany = try resolve("DE")
        #expect(!germany.provenance.isFallback)
        #expect(germany.provenance.level == PriceLevelProvenance(year: 2025, method: .exact))
    }

    @Test @MainActor func theNextIndexFillsTheGap() throws {
        let taiwan = try resolve("TW")
        #expect(taiwan.factor == money("0.44"))
        #expect(taiwan.provenance.kind == .index(.imf))
        #expect(taiwan.provenance.isFallback)
        #expect(taiwan.provenance.label == "IMF, Oct 2026")
        #expect(taiwan.provenance.detail == "IMF · Oct 2026 · Worked out from GDP figures")
        #expect(CountryProvenanceCell.name(taiwan.provenance) == "IMF · Oct 2026")
    }

    @Test func theRegionMedianComesLast() throws {
        let japan = try resolve("JP")
        #expect(japan.provenance.kind == .regionMedian(.worldBank) || japan.provenance.kind == .equalized)
        #expect(japan.provenance.isFallback)
        let canada = try resolve("CA")
        #expect(canada.provenance.kind == .regionMedian(.worldBank))
        #expect(canada.provenance.level == nil)
    }
}
