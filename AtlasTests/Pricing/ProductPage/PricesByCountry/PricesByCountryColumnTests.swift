//
//  PricesByCountryColumnTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("Prices by Country: columns")
struct PricesByCountryColumnTests {
    @Test func countryPriceAndChangeAlwaysShow() {
        let always = PricesByCountryColumn.allCases.filter(\.isAlwaysShown)
        #expect(always == [.country, .price, .change])
        #expect(PricesByCountryColumn.optional.count == PricesByCountryColumn.allCases.count - 3)
    }

    @Test func dollarsProceedsAndHowItsSetShowByDefault() {
        let state = PricesByCountryState()
        let shown = PricesByCountryColumn.allCases.filter(state.isShown)
        #expect(shown == [.country, .price, .dollars, .proceeds, .source, .change])
    }

    @Test func theColumnsMenuShowsAndHides() {
        let state = PricesByCountryState()
        state.setShown(.feelsLike, true)
        state.setShown(.dollars, false)
        #expect(state.isShown(.feelsLike))
        #expect(!state.isShown(.dollars))
        // The always-shown ones stay.
        state.setShown(.price, false)
        #expect(state.isShown(.price))
    }

    @Test func anotherProductKeepsTheFiltersAndColumnsButNotTheSelection() {
        let state = PricesByCountryState()
        state.show(productID: "a")
        state.filters.changedOnly = true
        state.setShown(.reason, true)
        state.selection = ["BRA"]
        state.search = "eur"
        state.show(productID: "b")
        #expect(state.filters.changedOnly)
        #expect(state.isShown(.reason))
        #expect(state.selection.isEmpty)
        #expect(state.search.isEmpty)
    }
}
#endif
