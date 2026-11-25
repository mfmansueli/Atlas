//
//  PricingViewModelGridTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Pricing section reads Apple's price points for its products: the
/// cards and their counts wait for them, the read-ahead respects the
/// hourly quota, a page the person opens reads anyway, and a push drops
/// what was read before it.
@MainActor
@Suite("Pricing · Apple's price points in the section")
struct PricingViewModelGridTests {
    private typealias Fixtures = PricingModelFixtures

    private func model(_ services: DebugPricingServices, readAhead quota: AppStoreConnectRateLimit? = nil) -> PricingViewModel {
        let modes = PricingModeStore(defaults: nil, modes: [Fixtures.appID: .showSuggestions])
        let model = PricingViewModel(app: Fixtures.app, services: services, queue: ChangeQueue(), modes: modes, commission: Fixtures.commission)
        if let quota { model.gridReadAhead = PricingGridReadAhead(quota: { quota }) }
        return model
    }

    private func loaded(_ model: PricingViewModel) async {
        await model.load()
        await model.productsTask?.value
    }

    @Test func cardsSuggestOnceThePointsArrive() async throws {
        let services = DebugPricingServices(simulatesGrid: true)
        let model = model(services)
        await loaded(model)
        let card = try #require(model.card(for: Fixtures.annual()))
        #expect(card.suggestion != nil)
        #expect(!card.isCheckingPrices)
        #expect(!services.calls.ladderRequests.isEmpty)
        #expect(model.openPriceSuggestionCount > 0)
    }

    @Test func aFailedReadLeavesNoSuggestionAndSaysWhy() async throws {
        var services = DebugPricingServices(simulatesGrid: true)
        services.laddersError = .server(statusCode: 500, code: "UNEXPECTED_ERROR", detail: "An unexpected error occurred on the server side.")
        let model = model(services)
        await loaded(model)
        let card = try #require(model.card(for: Fixtures.annual()))
        #expect(card.suggestion == nil)
        #expect(card.gridFailure != nil)
        #expect(model.openPriceSuggestionCount == 0)
        #expect(try model.countriesGrid(productID: Fixtures.annual().id)?.failure != nil)
    }

    @Test func readAheadWaitsWhileTheQuotaIsLow() async throws {
        let services = DebugPricingServices(simulatesGrid: true)
        let model = model(services, readAhead: AppStoreConnectRateLimit(limit: 3600, remaining: 200))
        await loaded(model)
        #expect(services.calls.ladderRequests.isEmpty)
        let card = try #require(model.card(for: Fixtures.annual()))
        #expect(card.isCheckingPrices)
        #expect(card.suggestion == nil)
        #expect(model.openPriceSuggestionCount == 0)

        // The section opens: read now, whatever the quota.
        model.gridReadAhead = nil
        await model.loadGrids()
        #expect(!services.calls.ladderRequests.isEmpty)
        #expect(try model.card(for: Fixtures.annual())?.suggestion != nil)
    }

    @Test func readAheadReadsWhileTheQuotaLeavesRoom() async {
        let services = DebugPricingServices(simulatesGrid: true)
        let model = model(services, readAhead: AppStoreConnectRateLimit(limit: 3600, remaining: 3000))
        await loaded(model)
        #expect(!services.calls.ladderRequests.isEmpty)
    }

    @Test func anOpenPageReadsWhateverTheQuota() async throws {
        let services = DebugPricingServices(simulatesGrid: true)
        let model = model(services, readAhead: AppStoreConnectRateLimit(limit: 3600, remaining: 10))
        await loaded(model)
        let productID = try Fixtures.annual().id
        #expect(model.countriesGrid(productID: productID) == .checking)
        await model.loadPageGrid(productID: productID)
        #expect(model.countriesGrid(productID: productID) == .ready)
    }

    @Test func inAppPurchasesReadNoGridAhead() async {
        let services = DebugPricingServices(simulatesGrid: true)
        let model = model(services)
        await loaded(model)
        let lifetime = model.countriesMatrix(productID: DebugPricingCatalog.lumenLifetimeID)
        #expect(lifetime?.needsGrid == false)
        #expect(model.countriesGrid(productID: DebugPricingCatalog.lumenLifetimeID) == nil)
    }

    @Test func aRecentPricePushDropsTheLaddersReadBeforeIt() async throws {
        let services = DebugPricingServices()
        let model = model(services)
        let product = try Fixtures.annual()
        let sheet = DebugPriceSheets.sheet(for: product, commission: Fixtures.commission, canReadSales: true)
        let territory = try PricingFixtures.territory("BRA")
        let current = try #require(sheet.prices["BRA"]?.current)
        let change = PriceChangeFactory(appID: Fixtures.appID, product: product).change(for: territory, from: current, to: current, source: .you)
        let now = Date()
        model.today = { now }
        let recent = PushRecord(date: now.addingTimeInterval(-3600), appID: Fixtures.appID, appName: "Lumen", title: "Prices", pushed: [change])
        let old = PushRecord(date: now.addingTimeInterval(-9 * 24 * 3600), appID: Fixtures.appID, appName: "Lumen", title: "Prices", pushed: [change])
        model.pushRecords = { [recent, old] }
        await model.forgetPushedLadders()
        #expect(services.calls.forgotten.map(\.productID) == [product.id])
        #expect(services.calls.forgotten.first?.before == recent.date)
    }

    @Test func pricedProductsAreReadFromChangeIDs() throws {
        let product = try Fixtures.annual()
        let sheet = DebugPriceSheets.sheet(for: product, commission: Fixtures.commission, canReadSales: true)
        let territory = try PricingFixtures.territory("DEU")
        let current = try #require(sheet.prices["DEU"]?.current)
        let change = PriceChangeFactory(appID: Fixtures.appID, product: product).change(for: territory, from: current, to: current, source: .you)
        #expect(PricingViewModel.pricedProductIDs(in: [change]) == [product.id])
        #expect(PricingViewModel.pricedProductIDs(in: []).isEmpty)
    }
}
#endif
