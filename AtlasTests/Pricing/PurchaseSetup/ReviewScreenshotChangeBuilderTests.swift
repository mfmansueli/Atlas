//
//  ReviewScreenshotChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A review screenshot in Review & Push: its own change for a product App
/// Store Connect has (what it replaces shown), or one more step of a new
/// product's change; and the file kept on this Mac until the push.
@MainActor
@Suite("PurchaseReviewScreenshotChangeBuilder")
struct ReviewScreenshotChangeBuilderTests {
    private static let app = NewSubscriptionChangeBuilderTests.app
    private static let lifetime = PricingProduct(
        id: "iap1", name: "Bruma Lifetime", productID: "com.lima.bruma.lifetime", isInAppPurchase: true, reviewState: "Missing Metadata"
    )
    private let folder = PurchaseReviewScreenshotFolder(root: FileManager.default.temporaryDirectory.appending(path: "ReviewShots-\(UUID().uuidString)"))

    private func file() throws -> PurchaseReviewScreenshotFile {
        try folder.save(EventArtworkTestFiles.png(width: 640, height: 1136), fileName: "Paywall.PNG", appID: "app1")
    }

    @Test func theFolderKeepsTheBytesWithTheirSizeAndChecksum() throws {
        let data = EventArtworkTestFiles.png(width: 640, height: 1136)
        let file = try folder.save(data, fileName: "Paywall.PNG", appID: "app1")
        #expect(file.pixelSize == PixelSize(width: 640, height: 1136))
        #expect(file.byteCount == data.count)
        #expect(file.checksum == ScreenshotPNG.checksum(data))
        #expect(file.pathExtension == "png")
        #expect(try Data(contentsOf: folder.url(for: file, appID: "app1")) == data)
        #expect(file.summary.contains("640 × 1136"))
    }

    @Test func anExistingProductsScreenshotIsItsOwnChange() throws {
        let file = try file()
        let builder = PurchaseReviewScreenshotChangeBuilder(app: Self.app, folder: folder)
        let change = builder.change(for: file, product: Self.lifetime, current: .uploaded(fileName: "old.png", checksum: "x"))
        #expect(change.id == PurchaseReviewScreenshotChangeBuilder.changeID(appID: "app1", productID: "com.lima.bruma.lifetime"))
        #expect(PurchaseReviewScreenshotChangeBuilder.owns(change))
        #expect(PurchaseSetupQueue.isSetup(change))
        #expect(change.oldValue == "old.png")
        #expect(change.newValue == file.summary)
        let step = try #require(PurchaseReviewScreenshotChangeBuilder.screenshot(in: change))
        #expect(step.owner == .inAppPurchase)
        #expect(step.ownerID == "iap1")
        #expect(step.path == folder.path(for: file, appID: "app1"))
    }

    @Test func aNewSubscriptionCarriesItsScreenshotAsItsLastStep() throws {
        var subscription = NewSubscriptionChangeBuilderTests.monthly()
        subscription.reviewScreenshot = try file()
        let change = NewSubscriptionChangeBuilder(app: Self.app, folder: folder).change(for: subscription)
        let step = try #require(change.requests.last.flatMap(PurchaseReviewScreenshotPush.init))
        #expect(step.owner == .subscription)
        #expect(step.ownerID == "{createdID:subscriptions}")
        #expect(change.creation?.fields.contains { $0.id == PurchaseReviewScreenshotChangeBuilder.fieldID } == true)
    }

    @Test func attachingReplacesTheStepAndKeepsTheChangesSource() throws {
        let first = try file()
        let second = try file()
        let builder = PurchaseReviewScreenshotChangeBuilder(app: Self.app, folder: folder)
        let created = NewInAppPurchaseChangeBuilder(app: Self.app).change(for: NewInAppPurchaseChangeBuilderTests.lifetime())
        let once = builder.attaching(first, owner: .inAppPurchase, to: created, source: .assistant(client: "Claude Code"))
        let twice = builder.attaching(second, owner: .inAppPurchase, to: once, source: .you)
        #expect(twice.source == created.source)
        #expect(twice.requests.count == created.requests.count + 1)
        #expect(PurchaseReviewScreenshotChangeBuilder.screenshot(in: twice)?.checksum == second.checksum)
        #expect(twice.creation?.fields.count { $0.id == PurchaseReviewScreenshotChangeBuilder.fieldID } == 1)
        #expect(PurchaseReviewScreenshotChangeBuilder.detaching(from: twice).requests == created.requests)
    }

    @Test func theQueueFindsTargetsByProductIDOrName() throws {
        let queue = ChangeQueue()
        let created = NewInAppPurchaseChangeBuilder(app: Self.app).change(for: NewInAppPurchaseChangeBuilderTests.lifetime())
        queue.upsert(created)
        let catalog = PricingCatalog(groups: [PricingProductGroup(id: "iaps", name: "In-App Purchases", isInAppPurchases: true, products: [Self.lifetime])])

        let existing = try #require(PurchaseSetupTarget.find("COM.LIMA.BRUMA.LIFETIME", appID: "app1", catalog: catalog, queue: queue))
        #expect(!existing.isQueued)
        #expect(existing.owner == .inAppPurchase)
        let queued = try #require(PurchaseSetupTarget.find("com.lima.bruma.lifetime", appID: "app1", catalog: nil, queue: queue))
        #expect(queued.isQueued)
        #expect(queued.usPrice == Decimal(string: "149.99"))
        #expect(PurchaseSetupTarget.find("nothing", appID: "app1", catalog: catalog, queue: queue) == nil)

        let setup = PurchaseSetupQueue(app: Self.app, queue: queue, folder: folder)
        #expect(try setup.queueReviewScreenshot(file(), for: queued, source: .you) == created.id)
        #expect(setup.queuedReviewScreenshot(for: queued) != nil)
        #expect(queue.changes.count == 1)
    }
}
