//
//  QueuedProductReviewScreenshotTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A new product waiting in Review & Push says when its review screenshot
/// is missing (`pr-newsub-noshot`): App Review needs one of the purchase
/// screen, or the product stays in Missing Metadata.
@MainActor
@Suite("Queued product review screenshot")
struct QueuedProductReviewScreenshotTests {
    @Test func aNewPurchaseWaitsWithoutAReviewScreenshot() async throws {
        let model = await PricingModelFixtures.viewModel()
        await model.productsTask?.value
        model.queueNewInAppPurchase(model.newInAppPurchaseDefaults())
        let change = try #require(model.queuedNewProducts.first)
        #expect(model.queuedNewProducts.count == 1)
        #expect(PurchaseReviewScreenshotChangeBuilder.screenshot(in: change) == nil)
    }

    @Test func theSceneOpens() {
        #expect(PricingDebugScenes.ids.contains("pr-newsub-noshot"))
        #expect(PricingDebugScenes.view(for: "pr-newsub-noshot") != nil)
    }
}
#endif
