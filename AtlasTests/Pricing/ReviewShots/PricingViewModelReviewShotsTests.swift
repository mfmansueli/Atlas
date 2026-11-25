//
//  PricingViewModelReviewShotsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Lumen's review screenshots on Pricing's cards (README — Pricing: review
/// screenshots): each card's state, Use This Capture and Use for All,
/// Accept, Accept All, Dismiss and Undo, and Make Review Screenshots….
/// Nothing is sent before the push; everything can be undone.
@MainActor
@Suite("PricingViewModel review screenshots")
final class PricingViewModelReviewShotsTests {
    private let queue = ChangeQueue()
    private let root = URL.temporaryDirectory.appending(path: "ReviewShotsTests-\(UUID().uuidString)")

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private let capture = ReviewShotsCapture(
        captureID: "paywall-png", number: 14, screenName: "Paywall", takenAt: .now, displayType: .iPhone, locale: "en-US",
        pixelSize: PixelSize(width: 640, height: 1136)
    )

    /// Lumen's three products, none with a review screenshot in App Store
    /// Connect but `uploaded`; Screenshots' paywall capture when `hasCapture`.
    private func model(hasCapture: Bool = true, uploaded: Set<String> = []) async throws -> PricingViewModel {
        let model = await PricingModelFixtures.viewModel(queue: queue)
        model.setup.details = ReviewShotDetailsStore()
        model.setup.runs = ReviewShotsRunCenter()
        model.setup.capturesRoot = root
        model.setup.folder = PurchaseReviewScreenshotFolder(root: root.appending(path: "Kept"))
        var states: [String: PurchaseReviewScreenshotState] = [:]
        for id in uploaded { states[id] = .uploaded(fileName: "old.png", checksum: nil) }
        model.setup.reader = DebugPurchaseExtrasReader(states: states)
        if hasCapture {
            let url = capture.url(appID: model.app.id, root: root)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try EventArtworkTestFiles.png(width: 640, height: 1136).write(to: url)
        }
        let found = hasCapture ? capture : nil
        model.setup.findPaywallCapture = { _ in found }
        await model.loadPurchaseExtras()
        return model
    }

    /// An image the assistant sent for `product`, as the MCP tool leaves it.
    private func suggest(_ product: PricingProduct, in model: PricingViewModel) throws {
        let file = try model.setup.folder.save(EventArtworkTestFiles.png(width: 640, height: 1136), fileName: "shot.png", appID: model.app.id)
        let id = try #require(model.setupQueue.queueReviewScreenshot(
            file, for: .existing(product), current: .missing, source: .assistant(client: "Claude Code"), at: .now
        ))
        var change = try #require(queue.change(id: id))
        change.awaitingAcceptance = "Look at it"
        queue.upsert(change)
        model.setup.details.set(ReviewShotDetails(origin: .assistant(client: "Claude Code"), plan: PricingViewModel.plan(of: product)), for: id)
    }

    @Test func missingCardsOfferTheCapture() async throws {
        let model = try await model(uploaded: [DebugPricingCatalog.lumenLifetimeID])
        let products = model.reviewShotProducts
        #expect(products.count == 3)
        #expect(model.reviewShotState(for: products[0]) == .missing(capture: capture))
        #expect(model.reviewShotState(for: products[2]) == .uploaded(.uploaded(fileName: "old.png", checksum: nil)))
        #expect(model.productsMissingReviewShot.count == 2)
        #expect(model.setup.runs.menuNote(for: model.app.id).text == "2 missing")
        #expect(products.map(PricingViewModel.plan(of:)) == ["Monthly", "Annual", "Lifetime"])
    }

    @Test func useForAllQueuesTheCaptureForEachAndUndoRemovesIt() async throws {
        let model = try await model()
        let missing = model.productsMissingReviewShot
        let ids = try model.useCapture(for: missing)
        #expect(ids.count == 3)
        #expect(model.useCaptureToast(for: missing) == "Capture 14 is the review screenshot for 3 products. In Review & Push.")
        for product in missing {
            guard case let .accepted(item) = model.reviewShotState(for: product) else {
                Issue.record("\(product.name) isn't waiting in Review & Push")
                continue
            }
            #expect(item.details?.acceptedLine == "Capture 14 · Paywall from Screenshots · sent when you push")
            #expect(FileManager.default.fileExists(atPath: item.fileURL.path(percentEncoded: false)))
            #expect(queue.change(id: item.changeID)?.awaitingAcceptance == nil, "The person chose it: nothing to accept")
        }
        #expect(model.productsMissingReviewShot.isEmpty)

        model.undoReviewShots(missing)
        #expect(queue.changes.isEmpty)
        #expect(model.productsMissingReviewShot.count == 3)
    }

    @Test func oneProductsToastNamesIt() async throws {
        let model = try await model()
        let monthly = try #require(model.reviewShotProducts.first)
        #expect(model.useCaptureToast(for: [monthly]) == "Capture 14 is now \(monthly.name)’s review screenshot. In Review & Push.")
    }

    @Test func anAssistantsImageIsSuggestedUntilAccepted() async throws {
        let model = try await model(hasCapture: false)
        let products = model.reviewShotProducts
        for product in products { try suggest(product, in: model) }
        #expect(model.productsWithSuggestedReviewShot.count == 3)
        #expect(model.reviewShotState(for: products[0]).isSuggested)

        model.acceptReviewShot(for: products[0])
        guard case .accepted = model.reviewShotState(for: products[0]) else {
            Issue.record("Accept leaves it in Review & Push")
            return
        }
        // Undo of an assistant's: back to a suggestion, not gone.
        model.undoReviewShot(for: products[0])
        #expect(model.reviewShotState(for: products[0]).isSuggested)

        let accepted = model.acceptAllReviewShots()
        #expect(accepted.count == 3)
        #expect(model.productsWithSuggestedReviewShot.isEmpty)
        #expect(queue.changes.allSatisfy { $0.awaitingAcceptance == nil })
    }

    @Test func dismissLeavesItMissingAndCanBeUndone() async throws {
        let model = try await model(hasCapture: false)
        let monthly = try #require(model.reviewShotProducts.first)
        try suggest(monthly, in: model)
        let id = model.reviewShotChangeID(for: monthly)
        let change = try #require(queue.change(id: id))
        let details = model.setup.details.details(for: id)

        model.dismissReviewShot(for: monthly)
        #expect(model.reviewShotState(for: monthly) == .missing(capture: nil))
        #expect(model.setup.details.details(for: id) == nil)

        model.restoreReviewShot(change, details: details)
        #expect(model.reviewShotState(for: monthly).isSuggested)
    }

    @Test func aRunShowsOnTheCards() async throws {
        let model = try await model(hasCapture: false)
        let products = model.reviewShotProducts
        model.startReviewShotsRun(client: "Claude Code")
        model.setup.runs.report(appID: model.app.id, productID: products[0].productID, step: "Opened Lumen in Simulator")
        #expect(model.reviewShotState(for: products[0]) == .working(steps: [], step: "Opened Lumen in Simulator", client: "Claude Code", plan: "Monthly"))
        #expect(model.reviewShotState(for: products[1]) == .queued("Claude Code captures Annual after Monthly."))
        #expect(model.reviewShotState(for: products[0]).isWorking)
    }

    @Test func makeReviewScreenshotsAsksForTheMissingOnes() async throws {
        let model = try await model(hasCapture: false, uploaded: [DebugPricingCatalog.lumenLifetimeID])
        var asked: (prompt: String, purpose: ClaudeCodeRunPurpose)?
        model.setup.startAsk = { prompt, purpose in
            asked = (prompt, purpose)
            return "Claude Code"
        }
        _ = await model.handle(.autopilot(.makeReviewScreenshots))
        let prompt = try #require(asked?.prompt)
        #expect(asked?.purpose == .reviewScreenshots(addsStoreKit: false), "Its own session, which may build and capture")
        #expect(prompt.contains("select Monthly"))
        #expect(prompt.contains("select Annual"))
        #expect(!prompt.contains("select Lifetime"), "Lifetime has one already")
        #expect(model.setup.runs.run(for: model.app.id)?.products.map(\.plan) == ["Monthly", "Annual"])
        #expect(model.productRoute == nil, "On the cards")
    }

    @Test func tryAgainKeepsWhereThePaywallIs() async throws {
        let model = try await model(hasCapture: false)
        var prompts: [String] = []
        var purposes: [ClaudeCodeRunPurpose] = []
        model.setup.startAsk = { prompt, purpose in
            prompts.append(prompt)
            purposes.append(purpose)
            return "Claude Code"
        }
        model.makeReviewScreenshots()
        model.setup.runs.fail(appID: model.app.id, .paywallNotFound(tried: ""))
        model.setup.paywallRoute = "Settings → Lumen Plus"
        model.tryReviewShotsAgain()
        #expect(prompts.count == 2)
        #expect(prompts.last?.contains("The person said the paywall is here: Settings → Lumen Plus.") == true)
        #expect(model.setup.runs.run(for: model.app.id)?.isWorking == true)

        model.setup.runs.fail(appID: model.app.id, .noPrices(saw: ""))
        model.makeReviewScreenshots(storeKit: true)
        #expect(purposes == [.reviewScreenshots(addsStoreKit: false), .reviewScreenshots(addsStoreKit: false), .reviewScreenshots(addsStoreKit: true)])
    }

    @Test func nothingMissingNothingAsked() async throws {
        let ids = Set([DebugPricingCatalog.lumenMonthlyID, DebugPricingCatalog.lumenAnnualID, DebugPricingCatalog.lumenLifetimeID])
        let model = try await model(uploaded: ids)
        var wasAsked = false
        model.setup.startAsk = { _, _ in
            wasAsked = true
            return nil
        }
        model.makeReviewScreenshots()
        #expect(!wasAsked)
        #expect(model.toast?.text == "Every product already has a review screenshot.")
        #expect(model.setup.runs.menuNote(for: model.app.id) == ("All set", false))
    }

    @Test func pricingsBadgeCountsSuggestedScreenshots() async throws {
        let model = try await model(hasCapture: false)
        let modes = PricingModeStore(defaults: nil, modes: [model.app.id: .keepPrices])
        let summaries = AppSummaryStore(services: .debug)
        #expect(SectionBadgeCounts.pricingCount(appID: model.app.id, summaries: summaries, modes: modes, changes: queue, retention: RetentionDraftStore()) == 0)
        for product in model.reviewShotProducts.prefix(2) { try suggest(product, in: model) }
        #expect(SectionBadgeCounts.pricingCount(appID: model.app.id, summaries: summaries, modes: modes, changes: queue, retention: RetentionDraftStore()) == 2)
    }
}
#endif
