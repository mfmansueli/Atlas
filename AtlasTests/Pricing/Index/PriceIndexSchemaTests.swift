//
//  PriceIndexSchemaTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Schema 2 of `PriceIndexSnapshot.json`: each value with its year and
/// method, editions with data year, fetch date and URL.
@Suite("PriceIndexSnapshot schema 2")
struct PriceIndexSchemaTests {
    private static let json = """
    {
      "schema": 2,
      "approximate": false,
      "note": "Published",
      "snapshotDate": "2026-11-25",
      "referenceTerritory": "USA",
      "sources": {
        "worldBank": {
          "edition": {
            "label": "2025 data, published 2026", "badge": "WB 2025", "provenanceLabel": "World Bank 2025",
            "date": "2026-11-11", "fetched": "2026-11-25", "dataYear": 2025,
            "url": "https://data.worldbank.org/indicator/PA.NUS.PPP", "method": "PPP / FCRF", "newerEdition": null
          },
          "levels": {
            "USA": { "level": 1, "year": 2025, "method": "exact" },
            "BRA": { "level": 0.4572, "year": 2025, "method": "exact" },
            "BGR": { "level": 0.4193, "year": 2024, "method": "fallback" }
          }
        },
        "bigMac": {
          "edition": { "label": "July 2026", "badge": "Big Mac Jul 26", "provenanceLabel": "Big Mac, Jul 2026", "date": "2026-07-01", "dataYear": 2026 },
          "levels": { "USA": { "level": 1, "year": 2026, "method": "exact" } },
          "shared": [ { "name": "Euro area", "level": 1.138, "year": 2026, "method": "exact", "territories": ["DEU", "FRA"] } ]
        }
      }
    }
    """

    private func snapshot() throws -> PriceIndexSnapshot {
        try PriceIndexSnapshot(jsonData: Data(Self.json.utf8))
    }

    @Test func decodesLevelsWithTheirProvenance() throws {
        let snapshot = try snapshot()
        #expect(!snapshot.isApproximate)
        #expect(snapshot.level(.worldBank, territoryID: "BRA") == PricingFixtures.money("0.4572"))
        let worldBank = try #require(snapshot.index(.worldBank))
        #expect(worldBank.levelProvenance(for: "BRA") == PriceLevelProvenance(year: 2025, method: .exact))
        #expect(worldBank.levelProvenance(for: "BGR") == PriceLevelProvenance(year: 2024, method: .fallback))
        #expect(worldBank.levelProvenance(for: "JPN") == nil)
        #expect(worldBank.fallbackCount == 1)
    }

    @Test func decodesTheEditionsDetails() throws {
        let edition = try #require(try snapshot().index(.worldBank)?.edition)
        #expect(edition.dataYear == 2025)
        #expect(edition.fetchDate == PricingSampleData.date("2026-11-25"))
        #expect(edition.date == PricingSampleData.date("2026-11-11"))
        #expect(edition.url?.absoluteString == "https://data.worldbank.org/indicator/PA.NUS.PPP")
        #expect(edition.provenanceLabel == "World Bank 2025")
        #expect(edition.newerEdition == nil)
    }

    @Test func sharedLevelsKeepTheirProvenance() throws {
        let bigMac = try #require(try snapshot().index(.bigMac))
        #expect(bigMac.level(for: "FRA") == PricingFixtures.money("1.138"))
        #expect(bigMac.levelProvenance(for: "DEU") == PriceLevelProvenance(year: 2026, method: .exact))
        #expect(bigMac.coverage == 3)
    }

    @Test func sampleFactorsAreExactOfTheEditionYear() throws {
        let sample = try PriceIndexSnapshot.sample()
        let worldBank = try #require(sample.index(.worldBank))
        #expect(worldBank.edition.dataYear == nil)
        #expect(worldBank.levelProvenance(for: "BRA") == PriceLevelProvenance(year: nil, method: .exact))
        #expect(worldBank.fallbackCount == 0)
    }

    @Test func editionRoundTripsThroughJSON() throws {
        let edition = try #require(try snapshot().index(.worldBank)?.edition)
        let decoded = try JSONDecoder().decode(PriceIndexEdition.self, from: JSONEncoder().encode(edition))
        #expect(decoded == edition)
    }
}
