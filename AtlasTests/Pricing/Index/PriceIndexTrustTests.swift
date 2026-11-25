//
//  PriceIndexTrustTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `PriceIndexSnapshot.trust(of:territoryID:asOf:)`, which HowSure reads.
@Suite("Price index trust")
struct PriceIndexTrustTests {
    private func snapshot(approximate: Bool = false, published: String = "2026-11-11") -> PriceIndexSnapshot {
        let edition = PriceIndexEdition(
            label: "2025 data", badge: "WB 2025", provenanceLabel: "World Bank 2025",
            date: PricingSampleData.date(published), newerEdition: nil, dataYear: 2025
        )
        let index = PriceIndex(
            source: .worldBank,
            edition: edition,
            levels: ["USA": 1, "BRA": PricingFixtures.money("0.46"), "BGR": PricingFixtures.money("0.42")],
            provenance: ["BGR": PriceLevelProvenance(year: 2024, method: .fallback)]
        )
        return PriceIndexSnapshot(
            isApproximate: approximate, note: "", snapshotDate: PricingSampleData.date("2026-11-25"),
            referenceTerritoryID: "USA", indices: [.worldBank: index]
        )
    }

    private let today = PricingSampleData.date("2026-11-25")

    @Test func exactAndFallbackValues() {
        #expect(snapshot().trust(of: .worldBank, territoryID: "BRA", asOf: today) == .exact)
        #expect(snapshot().trust(of: .worldBank, territoryID: "BGR", asOf: today) == .fallback)
        #expect(PriceIndexTrust.fallback.countsAsReal)
    }

    @Test func missingWithoutAValueOrSource() {
        #expect(snapshot().trust(of: .worldBank, territoryID: "JPN", asOf: today) == .missing)
        #expect(snapshot().trust(of: .imf, territoryID: "BRA", asOf: today) == .missing)
    }

    @Test func theSampleIsApproximate() throws {
        #expect(snapshot(approximate: true).trust(of: .worldBank, territoryID: "BRA", asOf: today) == .approximate)
        let sample = try PriceIndexSnapshot.sample()
        #expect(sample.trust(of: .worldBank, territoryID: "BRA", asOf: today) == .approximate)
        #expect(!PriceIndexTrust.approximate.countsAsReal)
    }

    @Test func staleAfterEighteenMonths() {
        let old = snapshot(published: "2025-05-01")
        #expect(old.trust(of: .worldBank, territoryID: "BRA", asOf: PricingSampleData.date("2026-11-01")) == .exact)
        #expect(old.trust(of: .worldBank, territoryID: "BRA", asOf: PricingSampleData.date("2026-11-02")) == .stale)
        #expect(old.trust(of: .worldBank, territoryID: "BGR", asOf: PricingSampleData.date("2026-11-02")) == .stale)
    }

    @Test func thePublishedSnapshotIsRealToday() throws {
        let snapshot = try PriceIndexSnapshot.bundled()
        let date = snapshot.snapshotDate
        #expect(snapshot.trust(of: .worldBank, territoryID: "BRA", asOf: date) == .exact)
        #expect(snapshot.trust(of: .worldBank, territoryID: "USA", asOf: date).countsAsReal)
    }
}
