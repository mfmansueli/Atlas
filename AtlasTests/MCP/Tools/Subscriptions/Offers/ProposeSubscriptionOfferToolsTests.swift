//
//  ProposeSubscriptionOfferToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_promotional_offer`, `propose_win_back_offer` and
/// `propose_offer_code`: checked against what App Store Connect has for the
/// subscription (read with the push's transport) and what waits in Review
/// & Push, queued for the person or refused with the reasons; and
/// `get_subscriptions` returning the offers.
@MainActor
@Suite("propose subscription offers")
struct ProposeSubscriptionOfferToolsTests {
    private let changes = ChangeQueue()
    private static let monthlyID = DebugPricingCatalog.lumenMonthlyID
    private static let quiet = StoreApp(id: DebugFixtures.AppID.quiet, name: "Quiet Timer", bundleID: "dev.northpier.quiet", primaryLocale: "en-US")

    /// Calls with Lumen Monthly's offers in App Store Connect when `hasOffers`.
    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], hasOffers: Bool = false, client: String = "Claude Code",
        modes: PricingModeStore? = nil
    ) async throws -> MCPToolOutcome {
        let push = FakePushTransport(remote: hasOffers ? SubscriptionOfferFixtures.remote(subscriptionID: Self.monthlyID) : [:])
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps + [Self.quiet], changes: changes, pricingModes: modes, push: push)
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: client))
    }

    private func reasons(_ outcome: MCPToolOutcome) -> [String] {
        outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    // MARK: - Promotional offers

    @Test func aPromotionalOfferIsQueuedWithItsReason() async throws {
        let outcome = try await call(ProposePromotionalOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly",
            "name": "Come back", "offerIdentifier": "lumen_comeback",
            "mode": "PAY_AS_YOU_GO", "duration": "ONE_MONTH", "numberOfPeriods": 3, "price": .double(1.99),
            "territoryPrices": ["BRA": .double(4.9)],
            "reason": "The paywall offers lapsed subscribers 3 months at $1.99", "evidence": ["Paywall/ComeBack.swift:22"],
        ])
        #expect(outcome.result["status"] == "queued")
        let id = PromotionalOfferChangeBuilder.changeID(appID: DebugFixtures.AppID.lumen, productID: "lumen.plus.monthly", identifier: "lumen_comeback")
        let change = try #require(changes.change(id: id))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.blockedReason == nil)
        let offer = try #require(PromotionalOfferChangeBuilder.offer(in: change))
        #expect(offer.terms.price == Decimal(string: "1.99"))
        #expect(offer.terms.territoryPrices["BRA"] == Decimal(string: "4.9"))
        #expect(SubscriptionOfferWrite(try #require(change.requests.first))?.plan.subscriptionID == Self.monthlyID)
        #expect(change.creation?.fields.first { $0.id == "evidence" }?.newValue.contains("Paywall/ComeBack.swift:22") == true)
    }

    @Test func anIdentifierAppStoreConnectHasIsRefused() async throws {
        let outcome = try await call(ProposePromotionalOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "name": "Again", "offerIdentifier": "come_back",
            "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
        ], hasOffers: true)
        #expect(outcome.result["status"] == "refused")
        #expect(reasons(outcome).contains(SubscriptionOfferProblem.identifierTaken(NewPromotionalOffer.identifierLabel, value: "come_back").message))
        #expect(changes.changes.isEmpty)
    }

    @Test func newPricesForAnOfferItHasArePatched() async throws {
        let outcome = try await call(ProposePromotionalOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "update_prices",
            "offerIdentifier": "come_back", "price": .double(1.99),
        ], hasOffers: true)
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.changes.first)
        #expect(change.requests.first?.method == .patch)
        #expect(change.requests.first?.path == "/v1/subscriptionPromotionalOffers/po1")
        #expect(change.conflictCheck?.expected == "2.99")

        // The same prices are nothing to change.
        let same = try await call(ProposePromotionalOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "update_prices",
            "id": "po1", "price": .double(2.99), "territories": ["BRA", "USA"],
        ], hasOffers: true)
        #expect(same.result["status"] == "refused")
    }

    @Test func deletingAnOfferItDoesntHaveIsRefused() async throws {
        let outcome = try await call(ProposePromotionalOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "delete", "offerIdentifier": "nope",
        ], hasOffers: true)
        #expect(outcome.result["status"] == "refused")
        let deleted = try await call(ProposePromotionalOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "delete", "id": "po1",
        ], hasOffers: true)
        #expect(deleted.result["status"] == "queued")
        #expect(changes.changes.first.map(PromotionalOfferChangeBuilder.isDeletion) == true)
    }

    @Test func paidOffersAreRefusedForAppsThatKeepTheirPrices() async throws {
        let modes = PricingModeStore(defaults: nil)
        modes.setMode(.keepPrices, for: "6450000003")
        let paid = try await call(ProposePromotionalOfferTool(), [
            "appId": "Tempo Metronome", "productId": "tempo.pro.monthly", "name": "Half", "offerIdentifier": "half",
            "mode": "PAY_UP_FRONT", "duration": "THREE_MONTHS", "price": .double(2.99),
        ], modes: modes)
        #expect(paid.result["status"] == "refused")
        #expect(reasons(paid).first?.contains("Keep my prices") == true || reasons(paid).first?.contains(PricingMode.keepPrices.title) == true)
        // A free one sets no price.
        let free = try await call(ProposePromotionalOfferTool(), [
            "appId": "Tempo Metronome", "productId": "tempo.pro.monthly", "name": "Month free", "offerIdentifier": "month_free",
            "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
        ], modes: modes)
        #expect(free.result["status"] == "queued")
    }

    @Test func aSubscriptionWaitingInReviewAndPushTakesOffersOnceItsPushed() async throws {
        _ = try await call(ProposeSubscriptionTool(), [
            "appId": "Quiet Timer", "group": "Quiet Plus", "groupDisplayName": "Quiet Plus",
            "referenceName": "Quiet Plus Yearly", "productId": "dev.northpier.quiet.plus.yearly", "duration": "ONE_YEAR",
            "displayName": "Quiet Plus", "description": "Every sound and timer", "price": .double(19.99),
        ])
        let outcome = try await call(ProposeOfferCodeTool(), [
            "appId": "Quiet Timer", "productId": "dev.northpier.quiet.plus.yearly", "name": "Launch",
            "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(reasons(outcome) == [SubscriptionOfferProblem.subscriptionNotCreated.message])
    }

    @Test func anotherSourcesChangeIsntReplaced() async throws {
        let arguments: [String: JSONValue] = [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "name": "Come back", "offerIdentifier": "lumen_comeback",
            "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
        ]
        _ = try await call(ProposePromotionalOfferTool(), arguments, client: "Codex")
        let outcome = try await call(ProposePromotionalOfferTool(), arguments, client: "Claude Code")
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.first?.source == .assistant(client: "Codex"))
    }

    @Test func badArgumentsAreErrorsToFix() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposePromotionalOfferTool(), [
                "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "name": "X", "offerIdentifier": "x",
                "mode": "HALF_OFF", "duration": "ONE_MONTH",
            ])
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposePromotionalOfferTool(), [
                "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "name": "X", "offerIdentifier": "x",
                "mode": "PAY_UP_FRONT", "duration": "THREE_MONTHS",
            ])
        }
    }

    // MARK: - Win-back offers

    @Test func aWinBackOfferIsQueuedWithItsEligibility() async throws {
        let outcome = try await call(ProposeWinBackOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly",
            "referenceName": "We miss you", "offerId": "lumen_winback", "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
            "paidMonths": 2, "sinceLastSubscribed": ["minimum": 1, "maximum": 6], "waitMonths": 6,
            "startDate": "2099-01-01", "endDate": "2099-02-28", "priority": "HIGH", "promotionIntent": "USE_AUTO_GENERATED_ASSETS",
        ])
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.changes.first)
        let offer = try #require(WinBackOfferChangeBuilder.offer(in: change))
        #expect(offer.settings.eligibility == WinBackEligibility(paidMonths: 2, sinceLastSubscribed: 1...6, waitMonths: 6))
        #expect(offer.settings.priority == .high)
        #expect(offer.settings.promotionIntent == .autoGeneratedAssets)
        #expect(offer.settings.endDate.map(NewIntroductoryOffer.dayString) == "2099-02-28")
    }

    @Test func aWinBackOfferStartingInThePastIsRefused() async throws {
        let outcome = try await call(ProposeWinBackOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly",
            "referenceName": "We miss you", "offerId": "lumen_winback", "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
            "startDate": "2020-01-01",
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(reasons(outcome).contains(SubscriptionOfferProblem.startsInThePast.message))
    }

    @Test func updatingAWinBackOfferSendsWhatChanged() async throws {
        let outcome = try await call(ProposeWinBackOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "update", "offerId": "we_miss_you",
            "priority": "NORMAL", "waitMonths": .null,
        ], hasOffers: true)
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.changes.first)
        let attributes = (PushPagedRead.body(of: try #require(change.requests.first))?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        #expect(Set(attributes?.keys.map(\.self) ?? []) == ["priority", "customerEligibilityWaitBetweenOffersInMonths"])

        let nothing = try await call(ProposeWinBackOfferTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "update", "id": "wb1", "priority": "HIGH",
        ], hasOffers: true)
        #expect(nothing.result["status"] == "refused")
        #expect(reasons(nothing).contains(SubscriptionOfferProblem.nothingChanged.message))
    }

    // MARK: - Offer codes

    @Test func anOfferCodeIsQueuedWithItsCodes() async throws {
        let outcome = try await call(ProposeOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "name": "Newsletter",
            "customerEligibilities": ["NEW", "EXPIRED"], "mode": "FREE_TRIAL", "duration": "ONE_MONTH",
            "customCode": ["code": "news30", "numberOfCodes": 500, "expirationDate": "2099-12-31"],
            "oneTimeCodes": ["numberOfCodes": 100, "expirationDate": "2099-12-31", "environment": "SANDBOX"],
        ], hasOffers: true)
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.changes.first)
        #expect(change.requests.count == 3)
        let code = try #require(OfferCodeChangeBuilder.offerCode(in: change))
        #expect(code.eligibilities == [.new, .expired])
        #expect(code.customCode?.code == "NEWS30")
        #expect(code.oneTimeCodes?.environment == .sandbox)
    }

    @Test func aCustomCodeTheAppHasIsRefused() async throws {
        let outcome = try await call(ProposeOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "add_custom_code", "name": "Podcast listeners",
            "customCode": ["code": "lumenpod", "numberOfCodes": 10],
        ], hasOffers: true)
        #expect(outcome.result["status"] == "refused")
        #expect(reasons(outcome).contains(SubscriptionOfferProblem.customCodeTaken("LUMENPOD").message))

        // Customers see it: App Review's rules apply.
        let android = try await call(ProposeOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "add_custom_code", "id": "oc1",
            "customCode": ["code": "ANDROID", "numberOfCodes": 10],
        ], hasOffers: true)
        #expect(android.result["status"] == "refused")
    }

    @Test func oneTimeCodesAndDeactivationsAreQueued() async throws {
        let batch = try await call(ProposeOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "add_one_time_codes", "id": "oc1",
            "oneTimeCodes": ["numberOfCodes": 200, "expirationDate": "2099-06-30"],
        ], hasOffers: true)
        #expect(batch.result["status"] == "queued")
        let off = try await call(ProposeOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "deactivate", "id": "oc1", "customCodeId": "cc1",
        ], hasOffers: true)
        #expect(off.result["status"] == "queued")
        #expect(changes.changes.count == 2)
        #expect(changes.changes.contains { $0.requests.first?.path == "/v1/subscriptionOfferCodeCustomCodes/cc1" })
    }

    // MARK: - get_subscriptions

    @Test func getSubscriptionsReturnsTheOffersAndWhatWaits() async throws {
        _ = try await call(ProposeOfferCodeTool(), [
            "appId": "Lumen Journal", "productId": "lumen.plus.monthly", "action": "deactivate", "id": "oc1",
        ], hasOffers: true)
        let outcome = try await call(GetSubscriptionsTool(), ["appId": "Lumen Journal"], hasOffers: true)
        let subscriptions = outcome.result["groups"]?.arrayValue?.flatMap { $0["subscriptions"]?.arrayValue ?? [] } ?? []
        let monthly = try #require(subscriptions.first { $0["productId"] == "lumen.plus.monthly" })

        let promotional = try #require(monthly["promotionalOffers"]?.arrayValue?.first)
        #expect(promotional["offerIdentifier"] == "come_back")
        #expect(promotional["mode"] == "PAY_AS_YOU_GO")
        #expect(promotional["territories"] == ["BRA", "USA"])
        let winBack = try #require(monthly["winBackOffers"]?.arrayValue?.first)
        #expect(winBack["offerId"] == "we_miss_you")
        #expect(winBack["sinceLastSubscribed"]?["maximum"] == 6)
        #expect(winBack["endDate"] == .null)
        let code = try #require(monthly["offerCodes"]?.arrayValue?.first)
        #expect(code["customCodes"]?.arrayValue?.first?["code"] == "LUMENPOD")
        #expect(code["oneTimeCodes"]?.arrayValue?.first?["numberOfCodes"] == 500)
        #expect(monthly["queuedOffers"]?.arrayValue?.count == 1)
        #expect(monthly["queuedOffers"]?.arrayValue?.first?["kind"] == "offerCode")
        #expect(outcome.result["offerRules"]?["nameLength"] == 64)
    }

    @Test func theToolsProposePricesAndAreInTheStandardToolbox() {
        for tool in [ProposePromotionalOfferTool().definition, ProposeWinBackOfferTool().definition, ProposeOfferCodeTool().definition] {
            #expect(tool.proposalKind == .prices)
            #expect(MCPToolbox.standard.tool(named: tool.name) != nil)
        }
    }
}
#endif
