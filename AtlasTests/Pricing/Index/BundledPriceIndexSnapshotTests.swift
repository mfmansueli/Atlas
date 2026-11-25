//
//  BundledPriceIndexSnapshotTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The published snapshot `fetch_price_index.py` writes before each release:
/// real figures, each with its year and method. Checks hold for any future
/// edition, so they keep passing when the file is regenerated.
@Suite("Bundled price index snapshot")
struct BundledPriceIndexSnapshotTests {
    private func bundled() throws -> PriceIndexSnapshot {
        try PriceIndexSnapshot.bundled()
    }

    @Test func isPublishedDataRelativeToTheUnitedStates() throws {
        let snapshot = try bundled()
        #expect(!snapshot.isApproximate)
        #expect(snapshot.referenceTerritoryID == "USA")
        for source in [PriceIndexSource.worldBank, .imf, .bigMac] {
            #expect(snapshot.level(source, territoryID: "USA") == 1, "\(source)")
        }
    }

    @Test func coversMostTerritoriesWithDistinctValues() throws {
        let snapshot = try bundled()
        #expect(snapshot.coverage(of: .worldBank) >= 140)
        #expect(snapshot.coverage(of: .imf) >= 140)
        #expect(snapshot.coverage(of: .bigMac) >= 45)
        let worldBank = try #require(snapshot.index(.worldBank))
        // The prototype had 34 distinct numbers for 165 territories.
        #expect(Set(worldBank.levels.values).count >= worldBank.coverage * 8 / 10)
    }

    @Test func everyLevelIsPlausible() throws {
        let snapshot = try bundled()
        for index in snapshot.indices.values {
            for (territoryID, level) in index.levels {
                #expect(level > Decimal(string: "0.08") ?? 0 && level < 3, "\(index.source) \(territoryID) \(level)")
            }
        }
    }

    @Test func everyTerritoryIDIsAnAppStoreTerritory() throws {
        let snapshot = try bundled()
        for index in snapshot.indices.values {
            for territoryID in index.levels.keys {
                #expect(TerritoryCatalog.standard.territory(alpha3: territoryID) != nil, "\(territoryID)")
            }
        }
    }

    @Test func labelsNameTheRealDataYear() throws {
        let snapshot = try bundled()
        let worldBank = try #require(snapshot.index(.worldBank)?.edition)
        let year = try #require(worldBank.dataYear)
        #expect(worldBank.provenanceLabel == "World Bank \(year)")
        #expect(worldBank.badge == "WB \(year)")
        #expect(worldBank.url != nil)
        #expect(worldBank.fetchDate != nil)
        let imf = try #require(snapshot.index(.imf)?.edition)
        let imfYear = try #require(imf.dataYear)
        // The IMF's latest year that is not a projection: the edition's year − 1.
        #expect(imfYear == Calendar.gmtGregorian.component(.year, from: imf.date) - 1)
        #expect(imf.provenanceLabel.hasPrefix("IMF, "))
        #expect(snapshot.index(.bigMac)?.edition.badge.hasPrefix("Big Mac ") == true)
    }

    @Test func valuesKeepTheirYearAndMethod() throws {
        let snapshot = try bundled()
        let worldBank = try #require(snapshot.index(.worldBank))
        let dataYear = try #require(worldBank.edition.dataYear)
        #expect(worldBank.levelProvenance(for: "USA") == PriceLevelProvenance(year: dataYear, method: .exact))
        for territoryID in worldBank.levels.keys {
            let provenance = try #require(worldBank.levelProvenance(for: territoryID))
            if provenance.method == .exact {
                #expect(provenance.year == dataYear, "\(territoryID)")
            } else {
                #expect((provenance.year ?? 0) >= dataYear - 2, "\(territoryID)")
            }
        }
    }

    @Test func bigMacEuroAreaIsShared() throws {
        let snapshot = try bundled()
        let germany = try #require(snapshot.level(.bigMac, territoryID: "DEU"))
        for territoryID in ["FRA", "ITA", "ESP", "NLD", "BGR"] {
            #expect(snapshot.level(.bigMac, territoryID: territoryID) == germany)
        }
    }

    @Test @MainActor func liveServicesUseThePublishedSnapshotAndSampleUsesTheSample() throws {
        let snapshot = try bundled()
        #expect(!snapshot.isApproximate)
        #expect(PricingSampleData.shared.snapshot.isApproximate)
        #expect(DebugPricingServices().indexSnapshot().isApproximate)
    }
}
