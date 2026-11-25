//
//  CountryPriceRowTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("Prices by Country: how it's set")
struct CountryPriceRowTests {
    private typealias Fixtures = CountryPriceRowFixtures

    @Test func howItsSetReadsTodayAndTheQueue() throws {
        #expect(try Fixtures.row("USA", current: "39.99", isBase: true, queued: Fixtures.queued("34.99")).source == .basePrice)
        #expect(try Fixtures.row("JPN", current: "6800").source == .automatic)
        #expect(try Fixtures.row("DEU", current: "44.99", followsApple: false).source == .setByYou)
        #expect(try Fixtures.row("JPN", current: "6800", queued: Fixtures.queued("5800")).source == .setByYou)
        #expect(try Fixtures.row("BRA", current: "249.90", queued: Fixtures.queued("129.90", source: .suggestion)).source == .acceptedSuggestion)
        #expect(try Fixtures.row(
            "BRA", current: "249.90", queued: Fixtures.queued("139.90", source: .suggestion), suggested: "129.90"
        ).source == .adjustedSuggestion)
        #expect(try Fixtures.row("DEU", current: "44.99", followsApple: false, queued: Fixtures.queued("42.99", automatic: true)).source == .automatic)
    }

    @Test func aWaitingChangeShowsItsPriceAndWhatItWas() throws {
        let row = try Fixtures.row("BRA", current: "249.90", queued: Fixtures.queued("199.90"))
        #expect(row.isPending)
        #expect(row.shownPriceText == "R$ 199,90")
        #expect(row.wasText == "was R$ 249,90")
        #expect(try Fixtures.row("BRA", current: "249.90").wasText == nil)
    }

    @Test func theChangeColumnShowsTheSuggestionThenWhatWaits() throws {
        let suggested = try Fixtures.row("BRA", current: "249.90", suggestion: "129.90")
        #expect(suggested.shownChange?.direction == .decrease)
        let waiting = try Fixtures.row("BRA", current: "249.90", queued: Fixtures.queued("299.90"))
        #expect(waiting.shownChange?.direction == .increase)
        #expect(try Fixtures.row("JPN", current: "6800").shownChange == nil)
    }

    @Test func findMatchesTheRegionToo() throws {
        let row = try Fixtures.row("BRA", current: "249.90")
        #expect(row.matches(search: "americas"))
        #expect(row.matches(search: "BRL"))
        #expect(!row.matches(search: "Europe"))
    }

    @Test func dollarsAreRoundedPastTen() {
        #expect(CountryPriceRow.dollarsText(Decimal(string: "46.2")) == "≈ $46")
        #expect(CountryPriceRow.dollarsText(Decimal(string: "4.99")) == "≈ $4.99")
        #expect(CountryPriceRow.dollarsText(nil) == "—")
    }

    @Test func theRowBuilderHidesDismissedAndQueuedSuggestions() async throws {
        let model = await PricingModelFixtures.viewModel()
        await model.productsTask?.value
        let annual = DebugPricingCatalog.lumenAnnualID
        let rows = try #require(model.countryRows(productID: annual))
        let suggested = try #require(rows.first { $0.hasSuggestion })

        model.dismissCountrySuggestion(productID: annual, territoryID: suggested.id)
        let after = try #require(model.countryRow(productID: annual, territoryID: suggested.id))
        #expect(!after.hasSuggestion)
        #expect(model.modes.dismissedCountries(productID: annual, appID: model.app.id) == [suggested.id])
    }
}
#endif
