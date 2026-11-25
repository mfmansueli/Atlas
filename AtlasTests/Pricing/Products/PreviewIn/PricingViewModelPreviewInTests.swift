//
//  PricingViewModelPreviewInTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// "Preview in" on Lumen Journal's sample products: every country the
/// products are sold in, the base territory first shown, each product's
/// price there, choosing a country and ‹ › through those with a change.
@MainActor
@Suite("Pricing preview in")
struct PricingViewModelPreviewInTests {
    private func loaded(queue: ChangeQueue = ChangeQueue()) async -> PricingViewModel {
        let model = await PricingModelFixtures.viewModel(queue: queue)
        await model.productsTask?.value
        return model
    }

    @Test func itListsEveryCountryAndOpensOnTheBaseTerritory() async throws {
        let model = await loaded()
        let countries = model.previewCountries
        let card = try #require(model.productCards.first)
        #expect(countries.count == card.territoryCount)
        #expect(!countries.changed.isEmpty, "the open suggestions change prices")
        let changed = Set(model.productCards.flatMap { $0.prices.filter { $0.value.next != nil }.keys })
        #expect(Set(countries.changed.map(\.id)) == changed)
        #expect(model.previewTerritory(in: countries)?.alpha2 == "US")
    }

    @Test func eachProductShowsItsPriceInTheCountry() async throws {
        let model = await loaded()
        let country = try #require(model.previewCountries.changed.first)
        let rows = model.previewRows(in: country.id)
        let prices = rows.compactMap { row -> PricingPreviewInPrice? in
            if case let .price(price) = row { return price }
            return nil
        }
        #expect(prices.count == rows.count, "every product's prices are read")
        #expect(prices.map(\.id) == model.productCards.filter { $0.prices[country.id] != nil }.map(\.id))
        #expect(prices.contains { $0.tag == .suggested })
        for price in prices {
            let card = try #require(model.productCards.first { $0.id == price.id })
            let territoryPrice = try #require(card.prices[country.id])
            #expect(price.price == territoryPrice.next ?? territoryPrice.now)
            #expect(price.oldPrice == (territoryPrice.next == nil ? nil : territoryPrice.now))
        }
    }

    @Test func acceptedPricesShowAsNotPushed() async throws {
        let model = await loaded()
        let open = try #require(model.productCards.first { $0.suggestion != nil })
        let territoryID = try #require(open.suggestion?.countries.first?.id)
        await model.acceptPriceSuggestion(productID: open.id)
        let row = model.previewRows(in: territoryID).first { $0.id == open.id }
        guard case let .price(price) = row else {
            Issue.record("No price for \(open.product.name) in \(territoryID)")
            return
        }
        #expect(price.tag == .notPushed)
        #expect(price.oldPrice != nil)
    }

    @Test func choosingACountryClosesTheMenu() async {
        let model = await loaded()
        model.isPreviewMenuPresented = true
        model.selectPreviewCountry("JPN")
        #expect(model.previewTerritoryID == "JPN")
        #expect(!model.isPreviewMenuPresented)
        #expect(model.previewTerritory(in: model.previewCountries)?.name == "Japan")
    }

    @Test func anUnknownCountryFallsBackToTheBaseTerritory() async {
        let model = await loaded()
        model.previewTerritoryID = "XXX"
        #expect(model.previewTerritory(in: model.previewCountries)?.id == "USA")
    }

    @Test func nextAndPreviousGoToTheCountriesWithAChange() async throws {
        let model = await loaded()
        let countries = model.previewCountries
        let first = try #require(countries.next(after: "USA"))
        model.showNextPreviewCountry()
        #expect(model.previewTerritoryID == first.id)
        #expect(countries.country(id: model.previewTerritoryID)?.hasChange == true)
        model.showNextPreviewCountry()
        let second = model.previewTerritoryID
        #expect(second == countries.next(after: first.id)?.id)
        model.showPreviousPreviewCountry()
        #expect(model.previewTerritoryID == countries.previous(before: second)?.id)
    }
}
#endif
