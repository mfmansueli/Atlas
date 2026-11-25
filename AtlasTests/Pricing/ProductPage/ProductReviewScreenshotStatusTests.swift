//
//  ProductReviewScreenshotStatusTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The product page's Review Screenshot status line: missing, a capture
/// ready, accepted, in App Store Connect, from the cards' state.
@MainActor
@Suite("Product review screenshot status")
struct ProductReviewScreenshotStatusTests {
    @Test func eachStateHasItsLine() {
        let cases: [(ReviewShotsCardState, ProductReviewScreenshotStatus, ProductReviewScreenshotStatus.Tone)] = [
            (.unknown, .notRead, .neutral),
            (.missing(capture: nil), .missing(hasCapture: false), .needsYou),
            (.queued("After Monthly"), .capturing(client: nil), .assistant),
            (.working(steps: [], step: "Opening the paywall", client: "Claude Code", plan: "Annual"), .capturing(client: "Claude Code"), .assistant),
            (.uploaded(.uploaded(fileName: "a.png", checksum: nil)), .inAppStoreConnect, .done),
            (.uploaded(.processing(fileName: "a.png")), .processing, .neutral),
            (.failed(.failed(fileName: "a.png")), .refused, .needsYou),
        ]
        for (state, status, tone) in cases {
            let made = ProductReviewScreenshotStatus.make(state)
            #expect(made == status)
            #expect(made.tone == tone)
        }
    }

    @Test func theLinesSayWhatToDo() {
        #expect(ProductReviewScreenshotStatus.missing(hasCapture: false).text == "Missing. Until it’s added, the product stays in Missing Metadata.")
        #expect(ProductReviewScreenshotStatus.missing(hasCapture: true).text == "Missing. Screenshots already has a capture of the paywall.")
        #expect(ProductReviewScreenshotStatus.captureReady(client: "Claude Code").text == "Claude Code captured one. Accept it in the product list.")
        #expect(ProductReviewScreenshotStatus.captureReady(client: nil).text == "The assistant captured one. Accept it in the product list.")
        #expect(ProductReviewScreenshotStatus.accepted.text == "Accepted. It’s in Review & Push.")
        #expect(ProductReviewScreenshotStatus.accepted.tone == .notPushed)
        #expect(ProductReviewScreenshotStatus.inAppStoreConnect.text == "In App Store Connect. Apple lets you replace it, not remove it.")
    }

    @Test func theViewModelReadsWhatAppStoreConnectHas() async throws {
        let model = await PricingModelFixtures.viewModel()
        model.setup.details = ReviewShotDetailsStore()
        model.setup.runs = ReviewShotsRunCenter()
        model.setup.findPaywallCapture = { _ in nil }
        model.setup.reader = DebugPurchaseExtrasReader(states: [
            DebugPricingCatalog.lumenLifetimeID: .uploaded(fileName: "lifetime.png", checksum: nil),
        ])
        let catalog = try #require(model.catalog)
        let annual = try #require(catalog.product(id: DebugPricingCatalog.lumenAnnualID))
        let lifetime = try #require(catalog.product(id: DebugPricingCatalog.lumenLifetimeID))
        #expect(model.reviewScreenshotStatus(for: annual) == .notRead)

        await model.loadReviewScreenshot(for: annual)
        await model.loadReviewScreenshot(for: lifetime)
        #expect(model.reviewScreenshotStatus(for: annual) == .missing(hasCapture: false))
        #expect(model.reviewScreenshotStatus(for: lifetime) == .inAppStoreConnect)
    }
}
#endif
