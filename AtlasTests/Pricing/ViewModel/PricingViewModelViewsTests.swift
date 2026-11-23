//
//  PricingViewModelViewsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Pricing tabs and views around the matrix: offers, results, the
/// schedule sheet and the intents that reach them.
@MainActor
@Suite("PricingViewModel views")
struct PricingViewModelViewsTests {
    @Test func startsOnTheTableOfPrices() async {
        let model = await PricingModelFixtures.viewModel()
        #expect(model.tab == .prices)
        #expect(model.display == .table)
        #expect(model.selectedProductID == DebugPricingCatalog.lumenAnnualID)
    }

    @Test func offersLoadOnceAndSelectThePromotionalOne() async {
        let model = await PricingModelFixtures.viewModel()
        await model.loadOffers()
        #expect(model.offers.value?.count == 4)
        #expect(model.selectedOffer?.id == "promo")
        model.selectedOfferID = "intro"
        await model.loadOffers()
        #expect(model.selectedOffer?.name == "1 week free")
    }

    @Test func offerPricesFollowTheShownPrice() async throws {
        let model = await PricingModelFixtures.viewModel()
        await model.loadOffers()
        let matrix = try #require(model.matrix)
        let promo = try #require(model.selectedOffer)
        let prices = matrix.offerPrices(for: promo)
        #expect(prices.count == 175)
        #expect(prices.prefix(3).map(\.territory.alpha2) == ["US", "IN", "BR"])
        let brazil = try #require(prices.first { $0.territory.alpha2 == "BR" })
        #expect(brazil.offerPrice?.customerPrice == PricingFixtures.money("109.90"))

        await matrix.applySuggestion(to: ["BRA"])

        let lowered = try #require(matrix.offerPrices(for: promo).first { $0.territory.alpha2 == "BR" })
        #expect(lowered.subscriptionPrice == PricingFixtures.money("109.90"))
        #expect(lowered.offerPrice?.customerPrice ?? 0 < PricingFixtures.money("109.90"))
        let trial = try #require(model.offers.value?.first { $0.paymentMode == .freeTrial })
        let trialIsFree = matrix.offerPrices(for: trial).allSatisfy(\.isFree)
        #expect(trialIsFree)
    }

    @Test func anInAppPurchaseKeepsTheOffersTabForItsOfferCodes() async throws {
        let model = await PricingModelFixtures.viewModel()
        model.tab = .offers
        await model.loadOffers()
        await model.select(productID: DebugPricingCatalog.lumenLifetimeID)
        #expect(model.tab == .offers)
        #expect(model.offers.value == nil)
        #expect(model.selectedOfferID == nil)
        model.setup.reader = DebugSubscriptionOffersReader()
        await model.loadOffers()
        let code = InAppPurchaseOfferCodesSampleData.offerCode
        #expect(model.offers.value?.map(\.id) == [ExistingInAppPurchaseOfferCode.offerID(code.id)])
        #expect(model.selectedOfferID == ExistingInAppPurchaseOfferCode.offerID(code.id))
        #expect(try model.canAddInAppPurchaseOfferCodes(to: #require(model.selectedProduct)))
    }

    @Test func anInAppPurchasesOfferCodesQueueFromPricing() async throws {
        let queue = ChangeQueue()
        let model = await PricingModelFixtures.viewModel(queue: queue)
        model.setup.reader = DebugSubscriptionOffersReader()
        await model.select(productID: DebugPricingCatalog.lumenLifetimeID)
        model.tab = .offers
        await model.loadOffers()
        let purchase = try #require(model.selectedProduct)
        let code = InAppPurchaseOfferCodesSampleData.offerCode
        // The name Lumen Lifetime has is taken; another one goes.
        #expect(model.problems(for: NewInAppPurchaseOfferCode(name: code.name, terms: .init(price: 0)), purchase: purchase)
            == [.inAppPurchaseOfferCodeNameTaken(code.name)])
        model.queueInAppPurchaseOfferCode(NewInAppPurchaseOfferCode(name: "Press", terms: .init(price: 0)), for: purchase)
        model.deactivate(.offerCode, in: code, of: purchase)
        #expect(model.queuedInAppPurchaseOfferCodes.count == 2)
        #expect(model.setup.inAppPurchaseOfferRoute == nil)
    }

    @Test func savingAScheduleRewritesTheQueue() async {
        let queue = ChangeQueue()
        let model = await PricingModelFixtures.viewModel(queue: queue)
        await model.applyRecommendedPrices()
        model.openSchedule()
        #expect(model.isScheduleSheetPresented)
        await model.loadSubscribers()
        #expect(model.subscribers?["CHE"] == 41)

        let schedule = PriceSchedule(startDay: "2026-11-02")
        model.saveSchedule(schedule)

        #expect(!model.isScheduleSheetPresented)
        #expect(model.matrix?.schedule == schedule)
        #expect(!queue.changes.isEmpty)
        #expect(queue.changes.allSatisfy { $0.groupNote == schedule.note })
    }

    @Test func resultsLoadPerProductAndReloadAfterAPush() async throws {
        let model = await PricingModelFixtures.viewModel()
        model.today = { PricingSampleData.date("2026-11-23") }
        model.pushRecords = { [DebugPricingResults.annualPush()].compactMap(\.self) }
        await model.loadResults()
        let first = try #require(model.results)
        #expect(first.summary?.countedCount == 17)

        await model.loadResults()
        #expect(model.results === first)

        model.resultsDidChange()
        #expect(model.results == nil)
    }

    @Test func intentsOpenTheirTab() async {
        let model = await PricingModelFixtures.viewModel()
        model.display = .map
        #expect(await model.handle(.showResults))
        #expect(model.tab == .results)
        #expect(await model.handle(.reviewSuggestions))
        #expect(model.tab == .prices)
        #expect(model.display == .table)
    }

    @Test func thePricingMenuShowsTheMapOrTheHistogram() async {
        let model = await PricingModelFixtures.viewModel()
        model.tab = .results
        #expect(await model.handle(.showPrices(.map)))
        #expect(model.tab == .prices)
        #expect(model.display == .map)
        #expect(await model.handle(.showPrices(.histogram)))
        #expect(model.display == .histogram)
    }

    @Test func editingTheScheduleFromReviewOpensTheSheet() async {
        let model = await PricingModelFixtures.viewModel()
        model.tab = .results
        #expect(await model.handle(.editPriceSchedule(productID: DebugPricingCatalog.lumenAnnualID)))
        // Nothing queued yet: there's nothing to schedule.
        #expect(model.tab == .prices)
        #expect(!model.isScheduleSheetPresented)

        await model.applyRecommendedPrices()
        #expect(await model.handle(.editPriceSchedule(productID: nil)))
        #expect(model.isScheduleSheetPresented)
    }
}
#endif
