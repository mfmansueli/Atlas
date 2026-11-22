//
//  ProposeInAppPurchaseToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_in_app_purchase`: an assistant's new in-app purchase queued as
/// one change, or refused with App Store Connect's reasons; and
/// `get_subscriptions` listing it while it waits.
@MainActor
@Suite("propose_in_app_purchase")
struct ProposeInAppPurchaseToolTests {
    private let changes = ChangeQueue()
    private static let quiet = StoreApp(id: DebugFixtures.AppID.quiet, name: "Quiet Timer", bundleID: "dev.northpier.quiet", primaryLocale: "en-US")

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue], client: String = "Claude Code") async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps + [Self.quiet], changes: changes)
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: client))
    }

    private func arguments(_ overrides: [String: JSONValue] = [:]) -> [String: JSONValue] {
        var arguments: [String: JSONValue] = [
            "appId": "Quiet Timer",
            "type": "NON_CONSUMABLE",
            "referenceName": "Quiet Lifetime",
            "productId": "dev.northpier.quiet.lifetime",
            "displayName": "Quiet Lifetime",
            "description": "Every sound and timer, once",
            "price": .double(29.99),
            "evidence": ["Quiet/Store.swift:12 — buys dev.northpier.quiet.lifetime"],
        ]
        arguments.merge(overrides) { $1 }
        return arguments
    }

    private var changeID: String {
        NewInAppPurchaseChangeBuilder.changeID(appID: Self.quiet.id, productID: "dev.northpier.quiet.lifetime")
    }

    @Test func aNewPurchaseIsQueuedAsTheAssistants() async throws {
        let outcome = try await call(ProposeInAppPurchaseTool(), arguments())

        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["changeId"] == .string(changeID))
        #expect(outcome.result["type"] == "NON_CONSUMABLE")
        #expect(outcome.result["missing"] != nil)
        let change = try #require(changes.change(id: changeID))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.requests.first?.path == "/v2/inAppPurchases")
        #expect(try InAppPurchaseStartingPrice(#require(change.requests.last))?.customerPrice == Decimal(string: "29.99"))
        #expect(change.creation?.fields.first { $0.id == "evidence" }?.newValue == "Quiet/Store.swift:12 — buys dev.northpier.quiet.lifetime")
        #expect(outcome.logLines == [.init(target: "Quiet Timer · Quiet Lifetime", outcome: .proposed)])
    }

    @Test func everythingAppStoreConnectWouldRefuseIsListed() async throws {
        let outcome = try await call(ProposeInAppPurchaseTool(), arguments([
            "displayName": .string(String(repeating: "a", count: 31)),
            "description": .string(String(repeating: "b", count: 46)),
        ]))
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reasons"]?.arrayValue?.count == 2)
        #expect(changes.changes.isEmpty)
    }

    @Test func appReviewsMetadataRulesAreKept() async throws {
        let outcome = try await call(ProposeInAppPurchaseTool(), arguments(["description": "Free forever, 50% off"]))
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.isEmpty)
    }

    @Test func aProductIDANewSubscriptionHasIsTaken() async throws {
        let subscription = NewSubscriptionChangeBuilder(app: Self.quiet).change(for: {
            var monthly = NewSubscriptionChangeBuilderTests.monthly()
            monthly.productID = "dev.northpier.quiet.lifetime"
            return monthly
        }())
        changes.upsert(subscription)
        let outcome = try await call(ProposeInAppPurchaseTool(), arguments())
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.count == 1)
    }

    @Test func anUnknownTypeIsAnArgumentError() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeInAppPurchaseTool(), arguments(["type": "AUTO_RENEWABLE"]))
        }
    }

    @Test func anotherSourcesPurchaseIsntReplaced() async throws {
        changes.upsert(NewInAppPurchaseChangeBuilder(app: Self.quiet).change(for: NewInAppPurchase(
            referenceName: "Quiet Lifetime", productID: "dev.northpier.quiet.lifetime", locale: .englishUS,
            displayName: "Quiet Lifetime", description: "Mine", price: Decimal(string: "19.99")
        )))
        let outcome = try await call(ProposeInAppPurchaseTool(), arguments())
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.first?.source == .you)
    }

    @Test func getSubscriptionsListsItWhileItWaits() async throws {
        _ = try await call(ProposeInAppPurchaseTool(), arguments())
        let outcome = try await call(GetSubscriptionsTool(), ["appId": "Quiet Timer"])
        let queued = try #require(outcome.result["queuedInAppPurchases"]?.arrayValue)
        #expect(queued.count == 1)
        #expect(queued.first?["productId"] == "dev.northpier.quiet.lifetime")
        #expect(queued.first?["reviewScreenshot"] == "MISSING")
        #expect(outcome.result["reviewScreenshotUploadURL"]?.stringValue?.contains("/review-screenshot/") == true)
        #expect(outcome.result["inAppPurchaseTypes"]?.arrayValue?.count == 3)
        #expect(outcome.result["offerDurations"]?["FREE_TRIAL"]?.arrayValue?.count == 8)
    }
}
#endif
