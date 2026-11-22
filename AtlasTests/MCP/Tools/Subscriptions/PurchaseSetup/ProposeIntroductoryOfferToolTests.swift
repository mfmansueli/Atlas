//
//  ProposeIntroductoryOfferToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_introductory_offer`: an offer for a subscription App Store
/// Connect has (its own change) or one queued by `propose_subscription`
/// (one more step of it), or refused with the reasons.
@MainActor
@Suite("propose_introductory_offer")
struct ProposeIntroductoryOfferToolTests {
    private let changes = ChangeQueue()
    private static let quiet = StoreApp(id: DebugFixtures.AppID.quiet, name: "Quiet Timer", bundleID: "dev.northpier.quiet", primaryLocale: "en-US")

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue], client: String = "Claude Code") async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps + [Self.quiet], changes: changes)
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: client))
    }

    @Test func aFreeTrialOnAnExistingSubscriptionIsItsOwnChange() async throws {
        let outcome = try await call(ProposeIntroductoryOfferTool(), [
            "appId": "Lumen Journal",
            "productId": "lumen.plus.monthly",
            "mode": "FREE_TRIAL",
            "duration": "ONE_WEEK",
            "reason": "The paywall promises a week free",
        ])
        #expect(outcome.result["status"] == "queued")
        let id = IntroductoryOfferChangeBuilder.changeID(appID: DebugFixtures.AppID.lumen, productID: "lumen.plus.monthly")
        #expect(outcome.result["changeId"] == .string(id))
        let change = try #require(changes.change(id: id))
        #expect(change.source == .assistant(client: "Claude Code"))
        let step = try #require(change.requests.first.flatMap(IntroductoryOfferEverywhere.init))
        #expect(step.subscriptionID == DebugPricingCatalog.lumenMonthlyID)
        #expect(step.offer == NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek))
        #expect(change.creation?.fields.first { $0.id == "evidence" }?.newValue == "The paywall promises a week free")
    }

    @Test func aQueuedSubscriptionCarriesItAsOneMoreStep() async throws {
        _ = try await call(ProposeSubscriptionTool(), [
            "appId": "Quiet Timer", "group": "Quiet Plus", "groupDisplayName": "Quiet Plus",
            "referenceName": "Quiet Plus Yearly", "productId": "dev.northpier.quiet.plus.yearly", "duration": "ONE_YEAR",
            "displayName": "Quiet Plus", "description": "Every sound and timer", "price": .double(19.99),
        ])
        let outcome = try await call(ProposeIntroductoryOfferTool(), [
            "appId": "Quiet Timer",
            "productId": "dev.northpier.quiet.plus.yearly",
            "mode": "PAY_UP_FRONT",
            "duration": "THREE_MONTHS",
            "price": .double(2.99),
            "territories": ["USA", "BRA"],
            "startDate": "2099-01-01",
        ])
        #expect(outcome.result["status"] == "queued")
        #expect(changes.changes.count == 1)
        let change = try #require(changes.changes.first)
        #expect(outcome.result["changeId"] == .string(change.id))
        let step = try #require(change.requests.last.flatMap(IntroductoryOfferEverywhere.init))
        #expect(step.subscriptionID == "{createdID:subscriptions}")
        #expect(step.offer.territories == .chosen(["USA", "BRA"]))
        #expect(step.offer.price == Decimal(string: "2.99"))
        #expect(step.offer.startDate.map(NewIntroductoryOffer.dayString) == "2099-01-01")

        // get_subscriptions shows it on the queued subscription.
        let read = try await call(GetSubscriptionsTool(), ["appId": "Quiet Timer"])
        #expect(read.result["queued"]?.arrayValue?.first?["introductoryOffer"] != nil)
    }

    @Test func termsAppStoreConnectRefusesAreListed() async throws {
        let outcome = try await call(ProposeIntroductoryOfferTool(), [
            "appId": "Lumen Journal",
            "productId": "lumen.plus.monthly",
            "mode": "PAY_AS_YOU_GO",
            "duration": "ONE_MONTH",
            "numberOfPeriods": 24,
            "price": .double(99),
            "territories": ["XYZ"],
        ])
        #expect(outcome.result["status"] == "refused")
        // Too many periods and an unknown territory (and the price, when
        // the subscription's is known).
        #expect((outcome.result["reasons"]?.arrayValue?.count ?? 0) >= 2)
        #expect(changes.changes.isEmpty)
    }

    @Test func anInAppPurchaseTakesNoIntroductoryOffer() async throws {
        let outcome = try await call(ProposeIntroductoryOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.lifetime", "mode": "FREE_TRIAL", "duration": "ONE_WEEK",
        ])
        #expect(outcome.result["status"] == "refused")
    }

    @Test func aPaidModeNeedsAPrice() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeIntroductoryOfferTool(), [
                "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "mode": "PAY_UP_FRONT", "duration": "ONE_MONTH",
            ])
        }
    }

    @Test func aDateThatIsntADayIsAnArgumentError() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeIntroductoryOfferTool(), [
                "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "mode": "FREE_TRIAL", "duration": "ONE_WEEK",
                "startDate": "next week",
            ])
        }
    }
}
#endif
