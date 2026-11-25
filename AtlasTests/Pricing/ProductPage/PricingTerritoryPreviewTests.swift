//
//  PricingTerritoryPreviewTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A country's price opened from Analytics' finding or a Reviews theme
/// (`price-br`): the product cards with "Preview in" on that country,
/// whatever Pricing showed before.
@MainActor
@Suite("Pricing territory preview")
struct PricingTerritoryPreviewTests {
    private func loaded() async -> PricingViewModel {
        let model = await PricingModelFixtures.viewModel()
        await model.productsTask?.value
        return model
    }

    @Test func showTerritoryPriceOpensTheCardsOnThatCountry() async {
        let model = await loaded()
        model.page = .retention
        model.openProduct(DebugPricingCatalog.lumenAnnualID)
        #expect(await model.handle(.showTerritoryPrice("BR")))
        #expect(model.page == .prices)
        #expect(model.productRoute == nil)
        #expect(model.previewTerritoryID == "BRA")
    }

    @Test func itLeavesAnOpenProductPage() async {
        let model = await loaded()
        model.openProduct(DebugPricingCatalog.lumenAnnualID)
        #expect(model.productRoute != nil)
        model.showTerritoryPreview(alpha2: "JP")
        #expect(model.productRoute == nil)
        #expect(model.previewTerritoryID == "JPN")
    }

    @Test func anUnknownCountryKeepsThePreviewWhereItWas() async {
        let model = await loaded()
        let before = model.previewTerritoryID
        model.showTerritoryPreview(alpha2: "ZZ")
        #expect(model.previewTerritoryID == before)
        #expect(model.productRoute == nil)
    }

    @Test func theSceneOpens() {
        #expect(PricingDebugScenes.ids.contains("price-br"))
        #expect(PricingDebugScenes.view(for: "price-br") != nil)
    }
}
#endif
