//
//  PricingProductReadFailureTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// One product's prices that App Store Connect's server failed to send.
/// On Atlas's own app (2026-11-22), right after pushing two new
/// subscriptions, one read answered 500 `UNEXPECTED_ERROR` and Pricing
/// showed "App Store Connect returned an error — App Store Connect returned
/// an error (500). An unexpected error occurred on the server side…" over
/// the whole section. Now the failure stays on that product, with Try
/// Again, and the read that failed is asked for again.
@MainActor
@Suite("Pricing · a product's prices that failed to read")
struct PricingProductReadFailureTests {
    private let appID = PricingModelFixtures.appID

    private func loaded(_ services: FlakyPricingServices, queue: ChangeQueue = ChangeQueue()) async -> (PricingViewModel, Notices) {
        let modes = PricingModeStore(defaults: nil, modes: [appID: .showSuggestions])
        let model = PricingViewModel(
            app: PricingModelFixtures.app, services: services, queue: queue, modes: modes, commission: PricingModelFixtures.commission
        )
        let notices = Notices()
        model.onNotice = { notices.list.append($0) }
        await model.load()
        await model.productsTask?.value
        return (model, notices)
    }

    @MainActor
    final class Notices {
        var list: [PushNotice] = []
    }

    private var monthlyID: String { DebugPricingCatalog.lumenMonthlyID }
    private var annualID: String { DebugPricingCatalog.lumenAnnualID }

    @Test func applesServerFailingOnOneProductStaysOnItsCard() async throws {
        let services = FlakyPricingServices()
        services.failures[monthlyID] = 1
        let (model, notices) = await loaded(services)
        let monthly = try #require(model.catalog?.product(id: monthlyID))

        #expect(model.areProductsLoaded)
        #expect(model.card(for: monthly) == nil)
        #expect(model.productErrors[monthlyID] == "Apple couldn’t send \(monthly.name)’s prices. Try again in a minute.")
        #expect(model.unreadProductIDs == [monthlyID])
        // The other products show, and no banner repeats Apple's text.
        #expect(model.productMatrices[annualID] != nil)
        #expect(model.matrix?.product.id == annualID)
        #expect(notices.list.isEmpty)

        await model.retryProduct(productID: monthlyID)
        #expect(model.card(for: monthly) != nil)
        #expect(model.productErrors[monthlyID] == nil)
        #expect(model.unreadProductIDs.isEmpty)
    }

    @Test func theSelectedProductIsReadAgainForItsCardAndShowsThatRead() async {
        let services = FlakyPricingServices()
        services.failures[annualID] = 1
        let (model, notices) = await loaded(services)

        // Its own read failed; the cards read it again, and that worked.
        #expect(services.sheetRequests.filter { $0 == annualID }.count == 2)
        #expect(model.productMatrices[annualID] != nil)
        #expect(model.matrix?.product.id == annualID)
        #expect(model.sheetError == nil)
        #expect(model.productErrors[annualID] == nil)
        #expect(notices.list.isEmpty)
    }

    @Test func aSelectedProductThatKeepsFailingSaysSoOnItself() async throws {
        let services = FlakyPricingServices()
        services.failures[annualID] = 2
        let (model, notices) = await loaded(services)
        let annual = try #require(model.catalog?.product(id: annualID))

        #expect(model.matrix == nil)
        #expect(model.sheetError == PricingReadFailure.text(productName: annual.name))
        #expect(!model.needsStartingPrice)
        #expect(!model.hasNoPrice)
        #expect(model.unreadProductIDs == [annualID])
        #expect(notices.list.isEmpty)
    }

    @Test func beingOfflineStillRaisesItsBanner() async {
        let services = FlakyPricingServices()
        services.error = URLError(.notConnectedToInternet)
        services.failures[annualID] = 1
        let (model, notices) = await loaded(services)

        #expect(notices.list == [.offline])
        #expect(model.unreadProductIDs.isEmpty)
    }

    @Test func refusalsKeepApplesWords() {
        #expect(PricingReadFailure.isProductFailure(AppStoreConnectError.server(statusCode: 503, detail: nil)))
        #expect(!PricingReadFailure.isProductFailure(AppStoreConnectError.server(statusCode: 400, code: "PARAMETER_ERROR", detail: nil)))
        #expect(!PricingReadFailure.isProductFailure(AppStoreConnectError.notFound(detail: nil)))
        #expect(!PricingReadFailure.isProductFailure(AppStoreConnectError.rateLimited))
        #expect(!PricingReadFailure.isProductFailure(URLError(.timedOut)))
    }

    /// While Review & Push is still setting a new subscription's starting
    /// prices (or stopped at "Prices · 14 of 175"), the countries priced so
    /// far aren't its prices yet: no "Lower the price in 13 countries".
    @Test func noSuggestionWhileItsStartingPricesAreStillBeingSet() async throws {
        let queue = ChangeQueue()
        let (model, _) = await loaded(FlakyPricingServices(), queue: queue)
        let open = try #require(model.productCards.first { $0.suggestion != nil })
        let before = model.openPriceSuggestionCount
        #expect(!open.isSettingStartingPrices)

        let setup = PendingChange(
            id: NewSubscriptionChangeBuilder.changeID(appID: appID, productID: open.product.productID),
            appID: appID, section: .subscriptionPricing, group: "Subscription Pricing · New subscriptions",
            title: open.product.name, oldValue: "", newValue: "1 year · $59.99", requests: []
        )
        queue.upsert(contentsOf: [setup])
        let card = try #require(model.card(for: open.product))
        #expect(card.suggestion == nil)
        #expect(card.isSettingStartingPrices)
        #expect(card.suggestedCount == 0)
        #expect(model.openPriceSuggestionCount == before - 1)

        // Pushed: the change leaves the queue and the suggestion is back.
        queue.discard(ids: [setup.id])
        #expect(model.card(for: open.product)?.suggestion != nil)
    }

    @Test func aSetStartingPriceWaitingCountsToo() async throws {
        let queue = ChangeQueue()
        let (model, _) = await loaded(FlakyPricingServices(), queue: queue)
        let annual = try #require(model.catalog?.product(id: annualID))
        #expect(!model.isSettingStartingPrices(of: annual))
        let change = PendingChange(
            id: NewSubscriptionChangeBuilder.startingPriceChangeID(appID: appID, productID: annual.productID),
            appID: appID, section: .subscriptionPricing, group: "Subscription Pricing", title: annual.name, oldValue: "", newValue: "$39.99",
            requests: []
        )
        queue.upsert(contentsOf: [change])
        #expect(model.isSettingStartingPrices(of: annual))
    }
}
#endif
