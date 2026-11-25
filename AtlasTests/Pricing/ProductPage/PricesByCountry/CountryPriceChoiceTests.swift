//
//  CountryPriceChoiceTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: the price popover's choice")
struct CountryPriceChoiceTests {
    private typealias Fixtures = CountryPriceRowFixtures

    @Test func opensOnTheSuggestion() throws {
        let row = try Fixtures.row("BRA", current: "249.90", suggestion: "129.90")
        let choice = CountryPriceChoice.opening(row)
        #expect(choice.mode == .suggested)
        #expect(choice.price == PricingFixtures.money("129.90"))
        #expect(choice.edit(for: row) == .price(PricingFixtures.money("129.90")))
        #expect(choice.primaryTitle(for: row) == "Accept R$ 129,90")
        #expect(choice.source(for: row) == .suggestion)
        #expect(!choice.isAdjusted(for: row))
    }

    @Test func aSteppedSuggestionIsAdjusted() throws {
        let row = try Fixtures.row("BRA", current: "249.90", suggestion: "129.90")
        var choice = CountryPriceChoice.opening(row)
        choice.price = PricingFixtures.money("139.90")
        #expect(choice.isAdjusted(for: row))
        #expect(choice.source(for: row) == .suggestion)
        #expect(choice.primaryTitle(for: row) == "Accept R$ 139,90")
    }

    @Test func withoutASuggestionSuggestedPriceFallsBackToChosen() throws {
        let row = try Fixtures.row("DEU", current: "44.99", followsApple: false)
        var choice = CountryPriceChoice.opening(row)
        choice.mode = .suggested
        #expect(choice.effectiveMode(for: row) == .chosen)
        #expect(choice.source(for: row) == .you)
    }

    @Test func anAcceptedSuggestionReopensOnSuggestedPrice() throws {
        let row = try Fixtures.row(
            "BRA", current: "249.90", queued: Fixtures.queued("129.90", source: .suggestion), suggested: "129.90"
        )
        let choice = CountryPriceChoice.opening(row)
        #expect(choice.mode == .suggested)
        // Already waiting at that price: nothing to accept.
        #expect(choice.edit(for: row) == nil)
    }

    @Test func stepsMoveOnePricePoint() {
        let points = ["119.90", "129.90", "139.90"].map(Fixtures.point)
        let price = PricingFixtures.money("129.90")
        #expect(CountryPriceChoice.step(price, by: 1, in: points) == PricingFixtures.money("139.90"))
        #expect(CountryPriceChoice.step(price, by: -1, in: points) == PricingFixtures.money("119.90"))
        #expect(CountryPriceChoice.step(PricingFixtures.money("139.90"), by: 1, in: points) == nil)
        // Between points: the next one in the step's direction.
        #expect(CountryPriceChoice.step(PricingFixtures.money("125"), by: 1, in: points) == PricingFixtures.money("129.90"))
        #expect(CountryPriceChoice.step(PricingFixtures.money("125"), by: -1, in: points) == PricingFixtures.money("119.90"))
        #expect(CountryPriceChoice.step(price, by: 1, in: []) == nil)
    }

    @Test func opensOnHowThePriceIsSet() throws {
        let automatic = try Fixtures.row("JPN", current: "6800")
        #expect(CountryPriceChoice.opening(automatic).mode == .automatic)
        // Already automatic: nothing to set.
        #expect(CountryPriceChoice.opening(automatic).edit(for: automatic) == nil)

        let chosen = try Fixtures.row("DEU", current: "44.99", automatic: "42.99", followsApple: false)
        var choice = CountryPriceChoice.opening(chosen)
        #expect(choice.mode == .chosen)
        #expect(choice.edit(for: chosen) == nil)
        choice.mode = .automatic
        #expect(choice.edit(for: chosen) == .automatic)
        #expect(choice.primaryTitle(for: chosen) == "Use Automatic Price")
    }

    @Test func anInAppPurchaseCanPinTodaysAutomaticPrice() throws {
        let row = try Fixtures.row("JPN", current: "6800", isInAppPurchase: true)
        var choice = CountryPriceChoice.opening(row)
        choice.mode = .chosen
        #expect(choice.edit(for: row) == .price(PricingFixtures.money("6800")))
    }

    @Test func theBaseHasOnlyItsPricePoints() throws {
        let row = try Fixtures.row("USA", current: "39.99", isBase: true, followsApple: false)
        var choice = CountryPriceChoice.opening(row)
        choice.mode = .automatic
        #expect(choice.effectiveMode(for: row) == .chosen)
        choice.price = PricingFixtures.money("34.99")
        #expect(choice.edit(for: row) == .price(PricingFixtures.money("34.99")))
    }
}
#endif
