//
//  PriceSourceTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 76: every Source label is "<source> · <edition>", and "Region
/// median" for the fallback, in the column, its help, the popover and the
/// inspector.
@Suite("PriceSourceText")
struct PriceSourceTextTests {
    private func edition(
        label: String, date: String, dataYear: Int?, badge: String = "", provenanceLabel: String? = nil
    ) -> PriceIndexEdition {
        PriceIndexEdition(
            label: label, badge: badge, provenanceLabel: provenanceLabel ?? label, date: PricingSampleData.date(date), newerEdition: nil,
            dataYear: dataYear
        )
    }

    private func index(_ source: PriceIndexSource, _ edition: PriceIndexEdition, year: Int? = nil) -> PriceProvenance {
        PriceProvenance(
            kind: .index(source), isFallback: false, edition: edition, level: year.map { PriceLevelProvenance(year: $0, method: .exact) }
        )
    }

    @Test func worldBankNamesItsDataYear() {
        let worldBank = edition(label: "World Bank 2025", date: "2026-07-01", dataYear: 2025)
        #expect(PriceSourceText.text(index(.worldBank, worldBank)) == "World Bank · 2025")
        #expect(PriceSourceText.text(.worldBank, edition: worldBank) == "World Bank · 2025")
    }

    @Test func anOlderValueNamesItsOwnYear() {
        let worldBank = edition(label: "World Bank 2025", date: "2026-07-01", dataYear: 2025)
        #expect(PriceSourceText.text(index(.worldBank, worldBank, year: 2024)) == "World Bank · 2024")
        #expect(PriceSourceText.text(index(.worldBank, worldBank, year: 2025)) == "World Bank · 2025")
    }

    @Test func imfAndBigMacNameTheirMonth() {
        let imf = edition(label: "IMF, Oct 2026", date: "2026-10-14", dataYear: 2026)
        #expect(PriceSourceText.text(index(.imf, imf)) == "IMF · Oct 2026")
        let bigMac = edition(label: "Big Mac, Jan 2026", date: "2026-01-20", dataYear: 2026)
        #expect(PriceSourceText.text(index(.bigMac, bigMac)) == "Big Mac · Jan 2026")
    }

    @Test func theSampleSnapshotReadsTheSameWay() {
        let snapshot = PricingSampleData.shared.snapshot
        let names = [PriceIndexSource.bigMac, .worldBank, .imf].compactMap { source in
            snapshot.index(source).map { PriceSourceText.text(source, edition: $0.edition) }
        }
        #expect(names == ["Big Mac · Jan 2026", "World Bank · 2024", "IMF · Apr 2026"])
    }

    @Test func aLabelWrittenDifferentlyFallsBackToTheEditionsOwnDate() {
        let worldBank = edition(label: "PPP 2025", date: "2026-07-01", dataYear: 2025)
        #expect(PriceSourceText.text(index(.worldBank, worldBank)) == "World Bank · 2025")
        // The month comes from the edition's day, in the person's language.
        let imf = edition(label: "WEO", date: "2026-10-14", dataYear: 2026)
        #expect(PriceSourceText.text(index(.imf, imf)) == "IMF · \(PriceSourceText.monthYear(imf.date))")
    }

    @Test func aCustomIndexGoesByItsBadgeAndMonth() {
        let custom = edition(label: "Imported Nov 20, 2026", date: "2026-11-20", dataYear: nil, badge: "Custom", provenanceLabel: "custom index")
        #expect(PriceSourceText.text(index(.custom, custom)) == "Custom · \(PriceSourceText.monthYear(custom.date))")
        #expect(PriceSourceText.monthYear(custom.date).contains("2026"))
    }

    @Test func fallbacksSayWhatTheyAre() {
        #expect(PriceSourceText.text(PriceProvenance(kind: .regionMedian(.worldBank), isFallback: true)) == "Region median")
        #expect(PriceSourceText.text(PriceProvenance(kind: .equalized, isFallback: true)) == "Equalized")
        #expect(PriceSourceText.text(PriceProvenance(kind: .regionalTier(.europe), isFallback: false)) == "Region tier")
        #expect(PriceSourceText.text(PriceProvenance(kind: .excluded, isFallback: false)) == "Excluded")
    }

    @Test func theHelpAddsWhyAFallbackValueStandsIn() {
        let worldBank = edition(label: "World Bank 2025", date: "2026-07-01", dataYear: 2025)
        let older = PriceProvenance(
            kind: .index(.worldBank), isFallback: true, edition: worldBank, level: PriceLevelProvenance(year: 2024, method: .fallback)
        )
        #expect(older.detail == "World Bank · 2024 · Its newest figure for this country")
        #expect(PriceProvenance(kind: .regionMedian(.worldBank), isFallback: true).detail == "Region median")
    }

    @Test func trailingReadsWhatFollowsTheName() {
        #expect(PriceSourceText.trailing("World Bank 2025", after: "World Bank") == "2025")
        #expect(PriceSourceText.trailing("IMF, Oct 2026", after: "IMF") == "Oct 2026")
        #expect(PriceSourceText.trailing("IMF", after: "IMF") == nil)
        #expect(PriceSourceText.trailing("Banco Mundial 2025", after: "World Bank") == nil)
    }
}
