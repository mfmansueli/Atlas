//
//  ProposePurchaseReviewScreenshotToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_purchase_review_screenshot` and `reviewScreenshot` in
/// `propose_subscription` / `propose_in_app_purchase`: a file sent to the
/// upload link, named by its fileId, queued for a product App Store Connect
/// has or a new one in Review & Push.
@MainActor
@Suite("propose_purchase_review_screenshot")
struct ProposePurchaseReviewScreenshotToolTests {
    private let changes = ChangeQueue()
    private static let quiet = StoreApp(id: DebugFixtures.AppID.quiet, name: "Quiet Timer", bundleID: "dev.northpier.quiet", primaryLocale: "en-US")

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps + [Self.quiet], changes: changes)
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    /// A paywall sent to the upload link for `appID`.
    private func upload(appID: StoreApp.ID) throws -> PurchaseReviewScreenshotFile {
        let file = try PurchaseReviewScreenshotFolder.shared.save(
            EventArtworkTestFiles.png(width: 640, height: 1136), fileName: "paywall.png", appID: appID
        )
        PurchaseReviewScreenshotUploads.shared.add(file, appID: appID)
        return file
    }

    @Test func anExistingProductGetsItsOwnChange() async throws {
        let file = try upload(appID: DebugFixtures.AppID.lumen)
        let outcome = try await call(ProposePurchaseReviewScreenshotTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "file": .string(file.id),
        ])
        #expect(outcome.result["status"] == "queued")
        let id = PurchaseReviewScreenshotChangeBuilder.changeID(appID: DebugFixtures.AppID.lumen, productID: "lumen.lifetime")
        let change = try #require(changes.change(id: id))
        let step = try #require(change.requests.first.flatMap(PurchaseReviewScreenshotPush.init))
        #expect(step.owner == .inAppPurchase)
        #expect(step.ownerID == DebugPricingCatalog.lumenLifetimeID)
        #expect(step.checksum == file.checksum)
        #expect(FileManager.default.fileExists(atPath: step.path))
        #expect(PurchaseReviewScreenshotChangeBuilder.owns(change))
    }

    @Test func aQueuedPurchaseCarriesItAsItsLastStep() async throws {
        let file = try upload(appID: Self.quiet.id)
        let outcome = try await call(ProposeInAppPurchaseTool(), [
            "appId": "Quiet Timer", "type": "NON_CONSUMABLE", "referenceName": "Quiet Lifetime",
            "productId": "dev.northpier.quiet.lifetime", "displayName": "Quiet Lifetime", "description": "Every sound, once",
            "price": .double(29.99), "reviewScreenshot": .string(file.id),
        ])
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["missing"] == nil)
        let change = try #require(changes.changes.first)
        let step = try #require(change.requests.last.flatMap(PurchaseReviewScreenshotPush.init))
        #expect(step.ownerID == "{createdID:inAppPurchases}")

        // Replaced later through the tool: still one step, the new file.
        let other = try upload(appID: Self.quiet.id)
        let again = try await call(ProposePurchaseReviewScreenshotTool(), [
            "appId": "Quiet Timer", "productId": "dev.northpier.quiet.lifetime", "file": .string(other.id),
        ])
        #expect(again.result["status"] == "queued")
        #expect(changes.changes.count == 1)
        let updated = try #require(changes.changes.first)
        #expect(updated.requests.count { PurchaseReviewScreenshotPush($0) != nil } == 1)
        #expect(PurchaseReviewScreenshotChangeBuilder.screenshot(in: updated)?.path.contains(other.id) == true)
    }

    @Test func aNewSubscriptionTakesOneToo() async throws {
        let file = try upload(appID: Self.quiet.id)
        let outcome = try await call(ProposeSubscriptionTool(), [
            "appId": "Quiet Timer", "group": "Quiet Plus", "groupDisplayName": "Quiet Plus",
            "referenceName": "Quiet Plus Monthly", "productId": "dev.northpier.quiet.plus.monthly", "duration": "ONE_MONTH",
            "displayName": "Quiet Plus", "description": "Every sound and timer", "price": .double(2.99),
            "reviewScreenshot": .string(file.id),
        ])
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.changes.first)
        let step = try #require(change.requests.last.flatMap(PurchaseReviewScreenshotPush.init))
        #expect(step.owner == .subscription)
        #expect(step.ownerID == "{createdID:subscriptions}")
    }

    @Test func anotherAppsFileIsntFound() async throws {
        let file = try upload(appID: DebugFixtures.AppID.lumen)
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposePurchaseReviewScreenshotTool(), [
                "appId": "Quiet Timer", "productId": "anything", "file": .string(file.id),
            ])
        }
    }

    @Test func anUnknownProductIsRefused() async throws {
        let file = try upload(appID: DebugFixtures.AppID.lumen)
        let outcome = try await call(ProposePurchaseReviewScreenshotTool(), [
            "appId": "Lumen Journal", "productId": "lumen.nothing", "file": .string(file.id),
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.isEmpty)
    }

    @Test func aThumbnailIsRefusedBeforeItsKept() {
        #expect(throws: PurchaseReviewScreenshotProblem.self) {
            _ = try PurchaseReviewScreenshotFolder.temporary.save(EventArtworkTestFiles.png(width: 100, height: 200), fileName: "tiny.png", appID: "app1")
        }
        #expect(throws: PurchaseReviewScreenshotProblem.self) {
            _ = try PurchaseReviewScreenshotFolder.temporary.save(Data("not an image".utf8), fileName: "notes.png", appID: "app1")
        }
    }

    @Test func getSubscriptionsShowsEachProductsScreenshotState() async throws {
        let outcome = try await call(GetSubscriptionsTool(), ["appId": "Lumen Journal"])
        let purchases = try #require(outcome.result["inAppPurchases"]?.arrayValue)
        #expect(purchases.allSatisfy { $0["reviewScreenshot"]?["state"] != nil })
        let subscriptions = outcome.result["groups"]?.arrayValue?.first?["subscriptions"]?.arrayValue ?? []
        #expect(!subscriptions.isEmpty)
        #expect(subscriptions.allSatisfy { $0["introductoryOffer"] != nil })
    }
}
#endif
