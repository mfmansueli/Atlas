//
//  PricesByCountryEmptyTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Prices by Country says when no row is left (board 73): the find
/// field's text first, else what each filter being empty means.
@Suite("PricesByCountryEmptyText")
struct PricesByCountryEmptyTextTests {
    @Test func aSearchThatMatchesNothingQuotesIt() {
        let empty = PricesByCountryEmptyText.make(filter: .suggested, search: "  Atlantis ")
        #expect(empty.text == "No results for “Atlantis”")
        #expect(empty.query == "Atlantis")
        #expect(empty.symbol == "magnifyingglass")
    }

    @Test func blankSearchFallsBackToTheFilter() {
        #expect(PricesByCountryEmptyText.make(filter: .suggested, search: "   ") == PricesByCountryEmptyText.make(filter: .suggested, search: ""))
    }

    @Test(arguments: [
        (PricesByCountryFilter.all, "No countries or regions.", "globe"),
        (.suggested, "No suggested prices left.", "checkmark.circle"),
        (.setByYou, "No prices set by you. Every country follows the base price.", "globe"),
        (.automatic, "Every price here is set by you.", "person.crop.circle"),
    ])
    func eachFilterSaysWhatItsEmptinessMeans(filter: PricesByCountryFilter, text: String, symbol: String) {
        let empty = PricesByCountryEmptyText.make(filter: filter, search: "")
        #expect(empty.text == text)
        #expect(empty.symbol == symbol)
    }

    @Test func everyFilterHasItsOwnText() {
        let texts = Set(PricesByCountryFilter.allCases.map { PricesByCountryEmptyText.make(filter: $0, search: "").text })
        #expect(texts.count == PricesByCountryFilter.allCases.count)
    }

    #if DEBUG
    @MainActor
    @Test func theEmptyFilterSceneOpens() {
        #expect(PricesByCountryDebugScenes.ids.contains("pr-prod-none"))
        #expect(PricesByCountryDebugScenes.view(for: "pr-prod-none") != nil)
    }
    #endif
}
