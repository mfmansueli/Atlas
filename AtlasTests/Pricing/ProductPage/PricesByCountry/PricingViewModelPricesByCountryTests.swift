//
//  PricingViewModelPricesByCountryTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("Prices by Country: changes in Review & Push")
struct PricingViewModelPricesByCountryTests {
    private let queue = ChangeQueue()
    private let annual = DebugPricingCatalog.lumenAnnualID
    private let lifetime = DebugPricingCatalog.lumenLifetimeID

    private func model() async -> PricingViewModel {
        let model = await PricingModelFixtures.viewModel(queue: queue)
        await model.productsTask?.value
        return model
    }

    private func row(_ model: PricingViewModel, _ productID: String, _ territoryID: String) throws -> CountryPriceRow {
        try #require(model.countryRow(productID: productID, territoryID: territoryID))
    }

    /// A point below today's, from Apple's ladder.
    private func lowerPoint(_ model: PricingViewModel, _ productID: String, _ territoryID: String) throws -> Decimal {
        let row = try row(model, productID, territoryID)
        let points = model.countryPricePoints(productID: productID, territoryID: territoryID)
        return try #require(points.last { $0.customerPrice < row.current.customerPrice * Decimal(9) / 10 }).customerPrice
    }

    @Test func aChosenPriceWaitsAsTheProductsOneRow() async throws {
        let model = await model()
        let price = try lowerPoint(model, annual, "BRA")
        await model.setCountryPrice(.price(price), productID: annual, territoryID: "BRA")

        let change = try #require(queue.change(id: PriceChangeFactory.changeID(productID: annual, territoryID: "BRA")))
        #expect(change.creation?.id == PricesByCountryChanges.creationID(productID: annual))
        #expect(change.creation?.title == "Pricing · Lumen Plus Annual")
        let formatted = CurrencyFormat.forCurrency("BRL").format(price)
        #expect(change.creation?.detail == "Brazil \(formatted). Applies when you push.")
        #expect(model.toast?.text == "Brazil: \(formatted) is in Review & Push.")
        #expect(model.toast?.canUndo == true)
        #expect(model.toast?.actionTitle == "Review & Push")

        let row = try row(model, annual, "BRA")
        #expect(row.isPending)
        #expect(row.source == .setByYou)
        #expect(row.wasText != nil)
    }

    @Test func severalCountriesShareOneReviewRow() async throws {
        let model = await model()
        let price = try lowerPoint(model, annual, "BRA")
        await model.setCountryPrice(.price(price), productID: annual, territoryID: "BRA")
        let mexico = try row(model, annual, "MEX")
        #expect(mexico.source == .setByYou)
        await model.setCountryPrice(.automatic, productID: annual, territoryID: "MEX")

        let creations = ReviewCreation.group(queue.changes)
        #expect(creations.count == 1)
        let creation = try #require(creations.first)
        #expect(creation.changes.count == 2)
        let formatted = CurrencyFormat.forCurrency("BRL").format(price)
        #expect(creation.detail == "Brazil \(formatted), Mexico back to automatic. Applies when you push.")
        #expect(model.toast?.text == "Mexico: Apple’s automatic price is in Review & Push.")
        #expect(try row(model, annual, "MEX").source == .automatic)
    }

    @Test func aSubscriptionsAutomaticPriceIsItsEqualizedOne() async throws {
        let model = await model()
        let mexico = try row(model, annual, "MEX")
        await model.setCountryPrice(.automatic, productID: annual, territoryID: "MEX")
        let change = try #require(queue.change(id: PriceChangeFactory.changeID(productID: annual, territoryID: "MEX")))
        #expect(change.newValue == mexico.currency.format(mexico.automatic.customerPrice))
        #expect(change.requests.count == 1)
    }

    @Test func undoInTheRowAndInTheToast() async throws {
        let model = await model()
        let price = try lowerPoint(model, annual, "BRA")
        await model.setCountryPrice(.price(price), productID: annual, territoryID: "BRA")
        model.undoCountryChange(productID: annual, territoryID: "BRA")
        #expect(queue.changes.isEmpty)
        #expect(try row(model, annual, "BRA").isPending == false)

        await model.setCountryPrice(.price(price), productID: annual, territoryID: "BRA")
        model.undoToast()
        #expect(queue.changes.isEmpty)
    }

    @Test func todaysPriceDropsTheChange() async throws {
        let model = await model()
        let brazil = try row(model, annual, "BRA")
        let price = try lowerPoint(model, annual, "BRA")
        await model.setCountryPrice(.price(price), productID: annual, territoryID: "BRA")
        await model.setCountryPrice(.price(brazil.current.customerPrice), productID: annual, territoryID: "BRA")
        #expect(queue.changes.isEmpty)
    }

    @Test func bulkActionsTakeTheSelection() async throws {
        let model = await model()
        let rows = try #require(model.countryRows(productID: annual))
        let suggested = Set(rows.filter(\.hasSuggestion).prefix(3).map(\.id))
        #expect(suggested.count == 3)
        model.pricesByCountry.selection = suggested
        await model.acceptCountrySuggestions(productID: annual, territoryIDs: suggested)
        #expect(queue.changes.count == 3)
        #expect(queue.changes.allSatisfy { $0.source == .suggestion })
        #expect(model.toast?.text == "3 suggested prices are in Review & Push.")
        #expect(model.pricesByCountry.selection.isEmpty)
        for id in suggested {
            #expect(try row(model, annual, id).source == .acceptedSuggestion)
        }

        let after = try #require(model.countryRows(productID: annual))
        let chosen = Set(after.filter { PricingViewModel.canGoAutomatic($0) && !$0.isPending }.prefix(2).map(\.id))
        try #require(!chosen.isEmpty)
        await model.setCountriesToAutomatic(productID: annual, territoryIDs: chosen)
        let expected = chosen.count == 1
            ? "Apple’s automatic price for 1 country is in Review & Push."
            : "Apple’s automatic price for \(chosen.count) countries is in Review & Push."
        #expect(model.toast?.text == expected)
        for id in chosen {
            #expect(try row(model, annual, id).source == .automatic)
        }
    }

    @Test func anInAppPurchaseWaitsAsOnePriceSchedule() async throws {
        let model = await model()
        let price = try lowerPoint(model, lifetime, "BRA")
        await model.setCountryPrice(.price(price), productID: lifetime, territoryID: "BRA")

        let change = try #require(queue.change(id: InAppPurchaseCountryPrices.changeID(productID: lifetime)))
        #expect(queue.changes.count == 1)
        #expect(change.blockedReason == nil)
        let request = try #require(change.requests.first)
        #expect(request.path == InAppPurchaseCountryPrices.path)
        let body = try #require(request.body.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("\"baseTerritory\""))
        #expect(body.contains("${price-BRA}"))
        #expect(body.contains("${price-USA}"))
        #expect(!change.restoreRequests.isEmpty)
        #expect(try row(model, lifetime, "BRA").source == .setByYou)

        // Back to automatic: Brazil leaves the schedule's manual prices.
        await model.setCountryPrice(.automatic, productID: lifetime, territoryID: "BRA")
        #expect(queue.changes.isEmpty)
    }
}
#endif
