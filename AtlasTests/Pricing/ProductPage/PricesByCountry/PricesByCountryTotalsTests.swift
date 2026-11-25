//
//  PricesByCountryTotalsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: the footer")
struct PricesByCountryTotalsTests {
    private typealias Fixtures = CountryPriceRowFixtures

    @Test func countsCountriesHeldBackAndNotPushed() throws {
        var rows = try Fixtures.sample()
        rows[1].likelyHeldBack = true
        let totals = PricesByCountryTotals(rows: rows, showsSuggestions: true)
        #expect(totals.text == "5 countries and regions · 1 likely held back by price · 1 not pushed")
    }

    @Test func withoutSuggestionsNothingIsHeldBack() throws {
        let totals = try PricesByCountryTotals(rows: Fixtures.sample(), showsSuggestions: false)
        #expect(totals.heldBackCount == nil)
        #expect(totals.text == "5 countries and regions · 1 not pushed")
    }
}
#endif
