//
//  PricingProductPageNavigationTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A product's page inside Pricing (board 73): the card, Show Countries and
/// "Preview in" open it on Prices by Country; the breadcrumb, ⌘[ and
/// Pricing chosen again in the sidebar go back to the cards.
@MainActor
@Suite("Pricing product page navigation")
struct PricingProductPageNavigationTests {
    private func loaded() async -> PricingViewModel {
        let model = await PricingModelFixtures.viewModel()
        await model.productsTask?.value
        return model
    }

    @Test func openingAProductShowsItsPageOnPricesByCountry() async throws {
        let model = await loaded()
        let monthly = DebugPricingCatalog.lumenMonthlyID
        model.openProduct(monthly)
        let route = try #require(model.productRoute)
        #expect(route.productID == monthly)
        #expect(route.tab == .pricesByCountry)
        #expect(route.filter == .all)
        #expect(route.focusedTerritory == nil)
        #expect(model.pageProduct?.id == monthly)

        // The product is selected, so its Offers tab reads its offers.
        await model.select(productID: monthly)
        #expect(model.selectedProductID == monthly)
        #expect(model.pageMatrix(for: monthly)?.product.id == monthly)
    }

    @Test func previewInOpensTheCountryItAsksFor() async throws {
        let model = await loaded()
        model.openProduct(DebugPricingCatalog.lumenAnnualID, territory: "BRA")
        let route = try #require(model.productRoute)
        #expect(route.focusedTerritory == "BRA")
        #expect(route.tab == .pricesByCountry)
    }

    @Test func showCountriesOpensTheSuggestedPrices() async throws {
        let model = await loaded()
        model.showSuggestedCountries(productID: DebugPricingCatalog.lumenAnnualID)
        let route = try #require(model.productRoute)
        #expect(route.filter == .suggested)
        #expect(route.tab == .pricesByCountry)
    }

    @Test func openingAgainStartsOnPricesByCountry() async {
        let model = await loaded()
        let annual = DebugPricingCatalog.lumenAnnualID
        model.openProduct(annual)
        model.productRoute?.tab = .details
        model.openProduct(annual)
        #expect(model.productRoute?.tab == .pricesByCountry)
    }

    @Test func aProductNotInTheCatalogOpensNothing() async {
        let model = await loaded()
        model.openProduct("not-a-product")
        #expect(model.productRoute == nil)
        #expect(model.pageProduct == nil)
    }

    @Test func backGoesToTheCards() async {
        let model = await loaded()
        model.openProduct(DebugPricingCatalog.lumenAnnualID)
        model.closeProduct()
        #expect(model.productRoute == nil)
        #expect(model.pageProduct == nil)
    }

    @Test func choosingPricingAgainLeavesThePage() async {
        let model = await loaded()
        model.openProduct(DebugPricingCatalog.lumenAnnualID)
        model.showProductList()
        #expect(model.productRoute == nil)
    }

    @Test func previousAndNextOpenTheNeighbouringProductsOnTheSameTab() async throws {
        let model = await loaded()
        let products = try #require(model.catalog?.products)
        try #require(products.count > 1)
        model.openProduct(products[0].id, tab: .details)
        #expect(model.adjacentProduct(-1) == nil)
        #expect(model.adjacentProduct(1)?.id == products[1].id)

        model.openAdjacentProduct(1)
        #expect(model.productRoute?.productID == products[1].id)
        #expect(model.productRoute?.tab == .details)

        model.openAdjacentProduct(-1)
        #expect(model.productRoute?.productID == products[0].id)
        // At the first product there's nothing before.
        model.openAdjacentProduct(-1)
        #expect(model.productRoute?.productID == products[0].id)
    }

    @Test func theResultsTabOpensFromTheRoute() async {
        let model = await loaded()
        model.openProduct(DebugPricingCatalog.lumenAnnualID, tab: .results)
        #expect(model.productRoute?.tab == .results)
        #expect(PricingProductTab.allCases == [.pricesByCountry, .results, .offers, .reviewScreenshot, .details])
    }

    @Test func pricesByCountryCountsTheOpenSuggestions() async throws {
        let model = await loaded()
        let annual = try PricingModelFixtures.annual()
        let card = try #require(model.card(for: annual))
        #expect(model.openSuggestionCount(for: annual) == (card.suggestion == nil ? 0 : card.suggestedCount))
        model.dismissPriceSuggestion(productID: annual.id)
        #expect(model.openSuggestionCount(for: annual) == 0)
    }

    @Test func theSectionChosenAgainIsCountedNotReopened() {
        let navigator = WorkspaceNavigator(section: .subscriptionPricing)
        navigator.choose(.subscriptionPricing)
        #expect(navigator.sectionChosenAgainCount == 1)
        #expect(navigator.section == .subscriptionPricing)

        navigator.choose(.reviews)
        #expect(navigator.section == .reviews)
        #expect(navigator.sectionChosenAgainCount == 1)
    }
}
#endif
