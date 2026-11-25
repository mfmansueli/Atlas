//
//  PricesByCountryFiltersTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: Filters")
struct PricesByCountryFiltersTests {
    private typealias Fixtures = CountryPriceRowFixtures

    @Test func theButtonCountsWhatsOn() {
        var filters = PricesByCountryFilters()
        #expect(filters.count == 0)
        #expect(!filters.isActive)
        filters.regions = [.europe, .americas]
        filters.increasesOnly = true
        #expect(filters.count == 3)
        #expect(filters.isActive)
    }

    @Test func regionsAndChangesNarrowTheRows() throws {
        let rows = try Fixtures.sample()
        var filters = PricesByCountryFilters(regions: [.americas])
        #expect(rows.filter(filters.matches).map(\.id) == ["USA", "BRA", "MEX"])
        filters.changedOnly = true
        // Brazil's suggestion and Mexico's waiting change.
        #expect(rows.filter(filters.matches).map(\.id) == ["BRA", "MEX"])
        filters.increasesOnly = true
        #expect(rows.filter(filters.matches).isEmpty)
    }

    @Test func fallbackOnlyKeepsFallbackFactors() throws {
        let fallback = PriceProvenance(kind: .regionMedian(.worldBank), isFallback: true)
        let rows = try [
            Fixtures.row("BRA", current: "249.90", provenance: PriceProvenance(kind: .index(.worldBank), isFallback: false)),
            Fixtures.row("MEX", current: "99", provenance: fallback),
        ]
        let filters = PricesByCountryFilters(fallbackOnly: true)
        #expect(rows.filter(filters.matches).map(\.id) == ["MEX"])
    }

    @Test func theLineSaysWhatsKept() {
        let filters = PricesByCountryFilters(regions: [.europe], increasesOnly: true)
        #expect(filters.summary == "Europe · Increases only")
        #expect(filters.line(shown: 2, of: 40) == "Europe · Increases only · 2 of 40 shown")
        #expect(PricesByCountryFilters().line(shown: 5, of: 5) == "5 of 5 shown")
    }

    @Test func theQueryAppliesFiltersToCountsToo() throws {
        let rows = try Fixtures.sample()
        let filters = PricesByCountryFilters(regions: [.americas])
        let counts = PricesByCountryQuery.counts(rows, filters: filters, search: "")
        #expect(counts[.all] == 3)
        #expect(counts[.suggested] == 1)
        let visible = PricesByCountryQuery.visible(rows, filter: .all, filters: filters, search: "", sortOrder: [])
        #expect(visible.map(\.id) == ["USA", "BRA", "MEX"])
    }
}
#endif
