//
//  PricingViewModelProductsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Pricing's Prices page on Lumen Journal's sample products: every product
/// is read for its card, and Accept, Accept All, Undo, Dismiss and Restore
/// change the queue and the cards. Nothing is pushed.
@MainActor
@Suite("Pricing products page")
struct PricingViewModelProductsTests {
    private func loaded(queue: ChangeQueue = ChangeQueue(), mode: PricingMode = .showSuggestions) async -> PricingViewModel {
        let model = await PricingModelFixtures.viewModel(queue: queue, mode: mode)
        await model.productsTask?.value
        return model
    }

    private func pricingChanges(_ queue: ChangeQueue) -> [PendingChange] {
        queue.changes(for: PricingModelFixtures.appID, section: .subscriptionPricing)
    }

    @Test func everyProductGetsACardAndTheOpenOnesAreCounted() async {
        let model = await loaded()
        #expect(model.areProductsLoaded)
        let cards = model.productCards
        #expect(!cards.isEmpty)
        #expect(cards.map(\.id) == (model.catalog?.products ?? []).map(\.id).filter { model.productMatrices[$0] != nil })
        #expect(model.openPriceSuggestionCount == cards.count { $0.suggestion != nil })
        #expect(model.openPriceSuggestionCount > 0)
        #expect(model.territoryCount == cards.first?.territoryCount)
        #expect(model.previewTerritory(in: model.previewCountries)?.alpha2 == "US")
    }

    @Test func acceptingOneQueuesItsPricesAndUndoTakesThemBack() async throws {
        let queue = ChangeQueue()
        let model = await loaded(queue: queue)
        let open = try #require(model.productCards.first { $0.suggestion != nil })
        let before = model.openPriceSuggestionCount

        await model.acceptPriceSuggestion(productID: open.id)
        #expect(model.toast?.text == "Accepted prices for \(open.product.name). In Review & Push.")
        #expect(model.toast?.canUndo == true)
        #expect(!pricingChanges(queue).isEmpty)
        #expect(model.card(for: open.product)?.suggestion == nil)
        #expect(model.openPriceSuggestionCount == before - 1)

        model.undoToast()
        #expect(model.toast == nil)
        #expect(pricingChanges(queue).isEmpty)
        #expect(model.card(for: open.product)?.suggestion != nil)
    }

    @Test func acceptAllAcceptsEveryOpenSuggestion() async {
        let queue = ChangeQueue()
        let model = await loaded(queue: queue)
        let count = model.openPriceSuggestionCount
        await model.acceptAllPriceSuggestions()
        #expect(model.openPriceSuggestionCount == 0)
        #expect(!pricingChanges(queue).isEmpty)
        let expected = count == 1 ? ". In Review & Push." : "Accepted prices for \(count) products, now in Review & Push."
        #expect(model.toast?.text.hasSuffix(expected) == true)
    }

    @Test func aDismissedSuggestionStaysAwayUntilRestored() async throws {
        let model = await loaded()
        let open = try #require(model.productCards.first { $0.suggestion != nil })

        model.dismissPriceSuggestion(productID: open.id)
        #expect(model.card(for: open.product)?.suggestion == nil)
        #expect(model.hasDismissedPriceSuggestions)

        model.restoreDismissedPriceSuggestions()
        #expect(model.card(for: open.product)?.suggestion != nil)
        #expect(!model.hasDismissedPriceSuggestions)
    }

    @Test func keepMyPricesHasNothingToSuggest() async {
        let model = await loaded(mode: .keepPrices)
        #expect(model.openPriceSuggestionCount == 0)
        #expect(model.productCards.allSatisfy { $0.suggestion == nil })
    }

    @Test func theBannerSaysHowManyProducts() async {
        let model = await loaded()
        let count = model.openPriceSuggestionCount
        let expected = count == 1
            ? "Price suggestions for 1 product. Review below or accept here."
            : "Price suggestions for \(count) products. Review below or accept all here."
        #expect(model.priceSuggestionsBannerText == expected)
    }
}
#endif
