//
//  PricingCardGridErrorTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Board 76: a product card whose Apple price points failed shows the error
/// template (what happened · what to do) with Try Again, which reads that
/// product's points again.
@MainActor
@Suite("Pricing · a card's price points that didn't load")
struct PricingCardGridErrorTests {
    private typealias Fixtures = PricingModelFixtures

    private func failingModel() -> (PricingViewModel, DebugPricingServices) {
        var services = DebugPricingServices(simulatesGrid: true)
        services.laddersError = .server(statusCode: 500, code: "UNEXPECTED_ERROR", detail: "An unexpected error occurred on the server side.")
        let modes = PricingModeStore(defaults: nil, modes: [Fixtures.appID: .showSuggestions])
        let model = PricingViewModel(app: Fixtures.app, services: services, queue: ChangeQueue(), modes: modes, commission: Fixtures.commission)
        return (model, services)
    }

    @Test func theCardCarriesWhatHappenedAndWhatToDo() async throws {
        let (model, _) = failingModel()
        await model.load()
        await model.productsTask?.value
        let card = try #require(model.card(for: Fixtures.annual()))
        let copy = try #require(card.gridFailure)
        #expect(copy.summary.hasPrefix(PriceGridState.failureTitle))
        #expect(copy.summary != PriceGridState.failureTitle)
        #expect(!copy.summary.contains("UNEXPECTED_ERROR"))
        #expect(card.suggestion == nil)
    }

    @Test func tryAgainReadsThatProductsPointsAgain() async throws {
        let (model, services) = failingModel()
        await model.load()
        await model.productsTask?.value
        let annual = try Fixtures.annual()
        let before = services.calls.ladderRequests.count
        await model.retryGrid(productID: annual.id)
        #expect(services.calls.ladderRequests.count > before)
        #expect(model.card(for: annual)?.gridFailure != nil)
    }

    @Test func theStateKeepsTheCopyAndItsText() {
        let copy = AppleErrorCopy(summary: "Apple’s price points didn’t load. Try again in a minute.", details: "500")
        let state = PriceGridState.failed(copy)
        #expect(state.failureCopy == copy)
        #expect(state.failure == copy.text)
        #expect(!state.isReady)
        #expect(PriceGridState.checking.failureCopy == nil)
    }
}
#endif
