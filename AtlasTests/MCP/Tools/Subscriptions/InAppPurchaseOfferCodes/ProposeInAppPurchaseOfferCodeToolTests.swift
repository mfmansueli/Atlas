//
//  ProposeInAppPurchaseOfferCodeToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_in_app_purchase_offer_code`: checked against the offer codes
/// App Store Connect has for the in-app purchase (read with the push's
/// transport) and what waits in Review & Push, queued for the person or
/// refused with the reasons; and `get_subscriptions` returning them.
@MainActor
@Suite("propose_in_app_purchase_offer_code")
struct ProposeInAppPurchaseOfferCodeToolTests {
    private let changes = ChangeQueue()
    private static let lifetimeID = DebugPricingCatalog.lumenLifetimeID

    /// Lumen Lifetime's offer code "Launch week" (custom code LUMENLIFE, a
    /// batch of one-time codes), as App Store Connect answers.
    private static var remote: [String: Data] {
        [
            InAppPurchaseOfferCodeResource.listPath(purchaseID: lifetimeID): Data("""
            {"data":[{"type":"inAppPurchaseOfferCodes","id":"ioc1","attributes":{"name":"Launch week",\
            "customerEligibilities":["NON_SPENDER"],"productionCodeCount":300,"sandboxCodeCount":0,"active":true}}]}
            """.utf8),
            InAppPurchaseOfferCodeResource.pricesPath(offerCodeID: "ioc1"): Data("""
            {"data":[{"id":"pr1","relationships":{"territory":{"data":{"type":"territories","id":"USA"}},\
            "pricePoint":{"data":{"type":"inAppPurchasePricePoints","id":"pp1"}}}}],
            "included":[{"type":"inAppPurchasePricePoints","id":"pp1","attributes":{"customerPrice":"39.99"}}]}
            """.utf8),
            InAppPurchaseOfferCodeResource.customCodesListPath(offerCodeID: "ioc1"):
                Data(#"{"data":[{"id":"cc1","attributes":{"customCode":"LUMENLIFE","numberOfCodes":2000,"active":true}}]}"#.utf8),
            InAppPurchaseOfferCodeResource.oneTimeCodesListPath(offerCodeID: "ioc1"): Data("""
            {"data":[{"id":"ot1","attributes":{"numberOfCodes":300,"expirationDate":"2099-03-31",\
            "createdDate":"2026-11-02T10:00:00Z","environment":"PRODUCTION","active":true}}]}
            """.utf8),
        ]
    }

    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], modes: PricingModeStore? = nil, client: String = "Claude Code"
    ) async throws -> MCPToolOutcome {
        let push = FakePushTransport(remote: Self.remote)
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps, changes: changes, pricingModes: modes, push: push)
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: client))
    }

    private func reasons(_ outcome: MCPToolOutcome) -> [String] {
        outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    @Test func anOfferCodeIsQueuedWithItsCodesAndReason() async throws {
        let outcome = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "Lumen Lifetime", "name": "Podcast listeners",
            "customerEligibilities": ["NON_SPENDER", "CHURNED_SPENDER"], "price": .double(29.99),
            "territoryPrices": ["BRA": .double(99.9)],
            "customCode": ["code": "PODCAST30", "numberOfCodes": 1000],
            "oneTimeCodes": ["numberOfCodes": 500, "expirationDate": "2099-12-31"],
            "reason": "The podcast ad promises Lifetime for $29.99", "evidence": ["Store/Promo.swift:8"],
        ])
        #expect(outcome.result["status"] == "queued")
        let id = InAppPurchaseOfferCodeChangeBuilder.changeID(appID: DebugFixtures.AppID.lumen, productID: "lumen.lifetime", name: "Podcast listeners")
        let change = try #require(changes.change(id: id))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.blockedReason == nil)
        let code = try #require(InAppPurchaseOfferCodeChangeBuilder.offerCode(in: change))
        #expect(code.eligibilities == [.nonSpender, .churnedSpender])
        #expect(code.terms.price == Decimal(string: "29.99"))
        #expect(code.terms.territoryPrices["BRA"] == Decimal(string: "99.9"))
        #expect(code.customCode?.code == "PODCAST30")
        #expect(code.oneTimeCodes?.numberOfCodes == 500)
        #expect(try InAppPurchaseOfferCodeWrite(#require(change.requests.first))?.plan.owner == .inAppPurchase(Self.lifetimeID))
        #expect(change.creation?.fields.first { $0.id == "evidence" }?.newValue.contains("Store/Promo.swift:8") == true)
    }

    @Test func aTakenNameAPriceNotBelowAndATakenCustomCodeAreRefused() async throws {
        let outcome = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "name": "Launch week", "price": .double(79.99),
            "customCode": ["code": "lumenlife", "numberOfCodes": 10],
        ])
        #expect(outcome.result["status"] == "refused")
        let reasons = reasons(outcome)
        #expect(reasons.contains(SubscriptionOfferProblem.inAppPurchaseOfferCodeNameTaken("Launch week").message))
        #expect(reasons.contains(SubscriptionOfferProblem.notBelowPurchasePrice("$79.99").message))
        #expect(reasons.count == 3)
        #expect(changes.changes.isEmpty)
    }

    @Test func aCustomCodeBreakingAppReviewsRulesIsRefused() async throws {
        let outcome = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "name": "Elsewhere", "price": 0,
            "customCode": ["code": "ANDROID", "numberOfCodes": 10],
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.isEmpty)
    }

    @Test func paidCodesAreRefusedForAppsThatKeepTheirPrices() async throws {
        let modes = PricingModeStore(defaults: nil)
        modes.setMode(.keepPrices, for: DebugFixtures.AppID.lumen)
        let paid = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "name": "Half", "price": .double(39.99),
        ], modes: modes)
        #expect(paid.result["status"] == "refused")
        #expect(changes.changes.isEmpty)
        let free = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "name": "Press", "price": 0,
        ], modes: modes)
        #expect(free.result["status"] == "queued")
    }

    @Test func codesAndDeactivationsForAnOfferCodeItHas() async throws {
        let custom = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "action": "add_custom_code", "id": "ioc1",
            "customCode": ["code": "SPRING", "numberOfCodes": 100],
        ])
        #expect(custom.result["status"] == "queued")
        let batch = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "action": "add_one_time_codes", "name": "Launch week",
            "oneTimeCodes": ["numberOfCodes": 50, "expirationDate": "2099-12-31", "environment": "SANDBOX"],
        ])
        #expect(batch.result["status"] == "queued")
        let off = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "action": "deactivate", "id": "ioc1", "customCodeId": "lumenlife",
        ])
        #expect(off.result["status"] == "queued")
        let deactivation = try #require(changes.changes.first { $0.requests.first?.method == .patch })
        #expect(deactivation.requests.first?.path == "/v1/inAppPurchaseOfferCodeCustomCodes/cc1")
        #expect(changes.changes.count == 3)

        let missing = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "action": "deactivate", "id": "nope",
        ])
        #expect(missing.result["status"] == "refused")
    }

    @Test func aSubscriptionIsSentToProposeOfferCode() async throws {
        let outcome = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "name": "Wrong", "price": 0,
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(reasons(outcome).first?.contains("propose_offer_code") == true)
        let other = try await call(ProposeOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "name": "Wrong", "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
        ])
        #expect(reasons(other).first?.contains("propose_in_app_purchase_offer_code") == true)
    }

    @Test func getSubscriptionsReturnsTheInAppPurchasesOfferCodes() async throws {
        _ = try await call(ProposeInAppPurchaseOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "name": "Press", "price": 0,
        ])
        let outcome = try await call(GetSubscriptionsTool(), ["appId": "Lumen Journal"])
        let purchases = outcome.result["inAppPurchases"]?.arrayValue ?? []
        let lifetime = try #require(purchases.first { $0["productId"] == "lumen.lifetime" })
        let code = try #require(lifetime["offerCodes"]?.arrayValue?.first)
        #expect(code["name"] == "Launch week")
        #expect(code["customerEligibilities"] == ["NON_SPENDER"])
        #expect(code["productionCodeCount"] == 300)
        #expect(code["territories"] == ["USA"])
        #expect(code["customCodes"]?.arrayValue?.first?["code"] == "LUMENLIFE")
        #expect(code["oneTimeCodes"]?.arrayValue?.first?["numberOfCodes"] == 300)
        #expect(lifetime["queuedOffers"]?.arrayValue?.first?["kind"] == "offerCode")
        #expect(outcome.result["offerRules"]?["activeOfferCodesPerInAppPurchase"] == 10)
    }

    @Test func theToolProposesPricesAndIsInTheStandardToolbox() {
        let tool = ProposeInAppPurchaseOfferCodeTool().definition
        #expect(tool.proposalKind == .prices)
        #expect(MCPToolbox.standard.tool(named: tool.name) != nil)
    }
}
#endif
