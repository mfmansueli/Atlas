//
//  PricingReviewShotsAfterPushTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Lumen's review screenshot cards around a push: a product the run
/// didn't capture, the one 640 × 920 copy after Apple refused a size, each
/// product read back from App Store Connect, and the toast once uploaded.
@MainActor
@Suite("PricingViewModel review screenshots after the push")
final class PricingReviewShotsAfterPushTests {
    private let queue = ChangeQueue()
    private let root = URL.temporaryDirectory.appending(path: "ReviewShotsAfterPushTests-\(UUID().uuidString)")
    private var records: [PushRecord] = []

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func model(uploaded: Set<String> = [], states: [String: ReviewShotProductState] = [:]) async -> PricingViewModel {
        let model = await PricingModelFixtures.viewModel(queue: queue)
        model.setup.details = ReviewShotDetailsStore()
        model.setup.runs = ReviewShotsRunCenter(since: .distantPast)
        model.setup.capturesRoot = root
        model.setup.folder = PurchaseReviewScreenshotFolder(root: root.appending(path: "Kept"))
        var remote: [String: PurchaseReviewScreenshotState] = [:]
        for id in uploaded { remote[id] = .uploaded(fileName: "shot.png", checksum: nil) }
        model.setup.reader = DebugPurchaseExtrasReader(states: remote)
        model.setup.stateReader = DebugReviewShotProductStateReader(states: states)
        model.setup.findPaywallCapture = { _ in nil }
        model.pushRecords = { [unowned self] in records }
        await model.loadPurchaseExtras()
        return model
    }

    /// A file of `width` × `height` queued by hand for `product`.
    private func queueFile(for product: PricingProduct, in model: PricingViewModel, width: Int = 1206, height: Int = 2622) throws -> PendingChange {
        let file = try model.setup.folder.save(EventArtworkTestFiles.png(width: width, height: height), fileName: "paywall.png", appID: model.app.id)
        model.queueReviewScreenshot(file, for: .existing(product))
        return try #require(queue.change(id: model.reviewShotChangeID(for: product)))
    }

    private func refuseSize(_ change: PendingChange, at date: Date = .now) {
        let refusal = PurchaseReviewScreenshotPushError.refused(fileName: "paywall.png", details: "The dimensions of the image are incorrect.")
        let text = refusal.localizedDescription
        records.append(PushRecord(
            date: date, appID: change.appID, appName: "Lumen", title: "", pushed: [], failures: [change.id: text], failedChanges: [change]
        ))
    }

    @Test func aProductTheRunSkippedSaysWhyOnItsCard() async {
        let model = await model()
        let products = model.reviewShotProducts
        model.startReviewShotsRun(client: "Claude Code")
        model.setup.runs.miss(appID: model.app.id, productID: products[1].productID, kind: .skipped, reason: "The paywall shows only Monthly")
        model.setup.runs.runEnded(appID: model.app.id)
        let miss = ReviewShotsMiss(kind: .skipped, reason: "The paywall shows only Monthly", client: "Claude Code")
        #expect(model.reviewShotState(for: products[1]) == .notCaptured(miss))
        #expect(model.productsMissingReviewShot.contains(products[1]), "Still missing: Review Screenshot… stays")
        #expect(ProductReviewScreenshotStatus.make(.notCaptured(miss)) == .missing(hasCapture: false))
    }

    @Test func aSizeRefusalOffersOne640By920Copy() async throws {
        let model = await model()
        let monthly = try #require(model.reviewShotProducts.first)
        let change = try queueFile(for: monthly, in: model)
        #expect(model.reviewShotSizeOffer(for: monthly) == nil, "Nothing refused yet")

        refuseSize(change)
        guard case .copy = model.reviewShotSizeOffer(for: monthly) else {
            Issue.record("Apple refused its size: the copy is offered")
            return
        }
        try model.useSizedCopy(for: monthly)
        let copy = try #require(queue.change(id: change.id))
        let path = try #require(PurchaseReviewScreenshotChangeBuilder.screenshot(in: copy)?.path)
        #expect(ReviewShotSizeCopy.pixelSize(at: path) == ReviewShotSizeCopy.size)
        #expect(copy.title == change.title)
        #expect(copy.awaitingAcceptance == nil, "Still accepted: it waits for the push")
        #expect(model.reviewShotSizeOffer(for: monthly) == nil, "The copy wasn't refused")

        refuseSize(copy, at: .now.addingTimeInterval(1))
        #expect(model.reviewShotSizeOffer(for: monthly) == .copyRefused, "Offered once")
    }

    @Test func thePushIsAnnouncedWithEachStateReadBack() async throws {
        let ids = Set([DebugPricingCatalog.lumenMonthlyID, DebugPricingCatalog.lumenAnnualID])
        let annualState = ReviewShotProductState(code: ReviewShotProductState.missingMetadata, gaps: [.groupLocalization])
        let model = await model(uploaded: ids, states: [DebugPricingCatalog.lumenAnnualID: annualState])
        let products = model.reviewShotProducts
        #expect(model.reviewShotProductState(for: products[1]) == annualState)
        #expect(model.reviewShotProductState(for: products[2]) == nil, "Not uploaded: not read back")
        #expect(model.toast == nil, "No push yet")

        let pushed = try products.prefix(2).map { try queueFile(for: $0, in: model) }
        records.append(PushRecord(date: .now, appID: model.app.id, appName: "Lumen", title: "", pushed: pushed))
        await model.loadPurchaseExtras()
        #expect(model.toast?.text == "Uploaded. Atlas read each product again from App Store Connect: 1 is Ready to Submit and 1 is Missing Metadata.")
        #expect(model.reviewShotUploadedLine(for: products[0]).hasPrefix("In App Store Connect since today."))
        #expect(model.reviewShotUploadedFile(for: products[0]) != nil, "The image it uploaded, for the thumbnail")

        model.toast = nil
        await model.loadPurchaseExtras()
        #expect(model.toast == nil, "Once per push")
    }
}
#endif
