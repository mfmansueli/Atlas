//
//  PushControllerPurchaseSetupTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing a new in-app purchase (create, texts into a version,
/// availability everywhere, its price schedule) and introductory offers,
/// on a subscription the same change creates or one App Store Connect has.
@MainActor
@Suite("PushController · in-app purchases and introductory offers")
struct PushControllerPurchaseSetupTests {
    private let queue = ChangeQueue()
    private let history = PushHistory()
    private static let app = NewSubscriptionChangeBuilderTests.app

    private static let iapPricePoints = "/v2/inAppPurchases/iap9/pricePoints?filter%5Bterritory%5D=USA"
        + "&fields%5BinAppPurchasePricePoints%5D=customerPrice&limit=8000"

    private static let versions = "/v2/inAppPurchases/iap9/versions?limit=200"
    private static let draft = Data(#"{"data":[{"id":"iv1","attributes":{"version":1,"state":"PREPARE_FOR_SUBMISSION"}}]}"#.utf8)

    /// Points at these US prices, `pp1`, `pp2`….
    private static func points(_ prices: [String]) -> Data {
        let items = prices.enumerated().map { #"{"id":"pp\#($0 + 1)","attributes":{"customerPrice":"\#($1)"}}"# }
        return Data(#"{"data":[\#(items.joined(separator: ","))]}"#.utf8)
    }

    private static func created(_ type: String, _ id: String) -> Data {
        Data(#"{"data":{"type":"\#(type)","id":"\#(id)"}}"#.utf8)
    }

    private static func inTerritory(_ id: String, _ territory: String) -> String {
        #"{"id":"\#(id)","relationships":{"territory":{"data":{"type":"territories","id":"\#(territory)"}}}}"#
    }

    private func push(_ changes: [PendingChange], via transport: FakePushTransport) async -> PushController {
        let controller = PushController(queue: queue, history: history, transport: transport)
        queue.upsert(contentsOf: changes)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    private func data(_ request: PushRequest) -> [String: Any] {
        PushPagedRead.body(of: request)?["data"] as? [String: Any] ?? [:]
    }

    // MARK: - In-app purchases

    @Test func aNewInAppPurchaseIsCreatedStepByStep() async {
        let transport = FakePushTransport(
            remote: [
                Self.versions: Self.draft,
                SubscriptionAvailabilityEverywhere.territoriesPath: Data(#"{"data":[{"id":"USA"},{"id":"BRA"}]}"#.utf8),
                Self.iapPricePoints: Self.points(["139.99", "149.99"]),
            ],
            responses: [
                "/v2/inAppPurchases": Self.created("inAppPurchases", "iap9"),
                "/v1/inAppPurchaseAvailabilities": Self.created("inAppPurchaseAvailabilities", "ia1"),
            ]
        )
        let change = NewInAppPurchaseChangeBuilder(app: Self.app).change(for: NewInAppPurchaseChangeBuilderTests.lifetime())
        let controller = await push([change], via: transport)

        #expect(controller.doneCount == 1)
        #expect(queue.changes.isEmpty)
        let sent = transport.sent
        #expect(sent.map(\.path) == [
            "/v2/inAppPurchases", "/v2/inAppPurchaseLocalizations", "/v1/inAppPurchaseAvailabilities", "/v1/inAppPurchasePriceSchedules",
        ])
        #expect(PushPagedRead.relationshipID("version", of: data(sent[1])) == "iv1")
        #expect(PushPagedRead.relationshipID("inAppPurchase", of: data(sent[2])) == "iap9")
        let territories = ((data(sent[2])["relationships"] as? [String: Any])?["availableTerritories"] as? [String: Any])?["data"] as? [[String: Any]]
        #expect(territories?.compactMap { $0["id"] as? String } == ["USA", "BRA"])
        // The point at exactly $149.99.
        let included = (PushPagedRead.body(of: sent[3])?["included"] as? [[String: Any]])?.first ?? [:]
        #expect(PushPagedRead.relationshipID("inAppPurchasePricePoint", of: included) == "pp2")
        #expect(PushPagedRead.relationshipID("inAppPurchase", of: data(sent[3])) == "iap9")
        let texts = sent.map { $0.path + (String(data: $0.body ?? Data(), encoding: .utf8) ?? "") }
        for placeholder in ["{createdID", "{inAppDraft:", "{iapStartingPrice:", "{everyTerritory}"] {
            #expect(!texts.contains { $0.contains(placeholder) })
        }
    }

    @Test func aPriceAppleDoesntHaveStopsThePushWithTheNearestOnes() async {
        let transport = FakePushTransport(
            remote: [
                Self.versions: Self.draft,
                SubscriptionAvailabilityEverywhere.territoriesPath: Data(#"{"data":[{"id":"USA"}]}"#.utf8),
                Self.iapPricePoints: Self.points(["139.99", "159.99"]),
            ],
            responses: ["/v2/inAppPurchases": Self.created("inAppPurchases", "iap9")]
        )
        let change = NewInAppPurchaseChangeBuilder(app: Self.app).change(for: NewInAppPurchaseChangeBuilderTests.lifetime())
        let controller = await push([change], via: transport)

        #expect(controller.doneCount == 0)
        #expect(queue.changes.count == 1)
        #expect(!transport.sent.contains { $0.path == InAppPurchaseStartingPrice.path })
        let error = InAppPurchasePriceError.noPricePoint(
            price: Decimal(string: "149.99") ?? 0, territoryID: "USA", nearest: [Decimal(string: "139.99") ?? 0, Decimal(string: "159.99") ?? 0]
        )
        #expect(error.errorDescription?.isEmpty == false)
    }

    // MARK: - Introductory offers

    @Test func aNewSubscriptionsFreeTrialGoesWhereItsSoldAndSkipsTerritoriesThatHaveOne() async {
        let sub = "sub9"
        let offer = IntroductoryOfferEverywhere(subscriptionID: sub, offer: NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek))
        let transport = FakePushTransport(
            remote: [
                "/v1/subscriptions/sub9/versions?limit=200": Data(#"{"data":[{"id":"sv1","attributes":{"version":1,"state":"PREPARE_FOR_SUBMISSION"}}]}"#.utf8),
                SubscriptionAvailabilityEverywhere.territoriesPath: Data(#"{"data":[{"id":"USA"},{"id":"BRA"},{"id":"GBR"}]}"#.utf8),
                "/v1/subscriptions/sub9/pricePoints?filter%5Bterritory%5D=USA&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000":
                    Data(#"{"data":[{"id":"p2","attributes":{"customerPrice":"9.99"}}]}"#.utf8),
                offer.availabilityPath: Data(#"{"data":{"id":"av1"}}"#.utf8),
                IntroductoryOfferEverywhere.availableTerritoriesPath(availabilityID: "av1"): Data(#"{"data":[{"id":"USA"},{"id":"BRA"},{"id":"GBR"}]}"#.utf8),
                offer.offersPath: Data(#"{"data":[\#(Self.inTerritory("o1", "GBR"))]}"#.utf8),
            ],
            responses: [
                "/v1/subscriptionGroups": Self.created("subscriptionGroups", "grp9"),
                "/v1/subscriptions": Self.created("subscriptions", sub),
                "/v1/subscriptionGroupVersions": Self.created("subscriptionGroupVersions", "gv1"),
                "/v1/subscriptionAvailabilities": Self.created("subscriptionAvailabilities", "av1"),
            ]
        )
        let created = NewSubscriptionChangeBuilder(app: Self.app).change(for: NewSubscriptionChangeBuilderTests.monthly())
        let change = IntroductoryOfferChangeBuilder.attaching(offer.offer, to: created, source: .you)
        let controller = await push([change], via: transport)

        #expect(controller.doneCount == 1)
        let offers = transport.sent.filter { $0.path == IntroductoryOfferEverywhere.path }
        #expect(offers.map { PushPagedRead.relationshipID("territory", of: data($0)) } == ["USA", "BRA"])
        #expect(offers.allSatisfy { PushPagedRead.relationshipID("subscription", of: data($0)) == sub })
        #expect(offers.allSatisfy { PushPagedRead.relationshipID("subscriptionPricePoint", of: data($0)) == nil })
        #expect(offers.allSatisfy { PushPagedRead.body(of: $0)?["atlas"] == nil })
        // After the subscription's own prices: a PATCH of the subscription
        // with inline price creates, or POSTs when that's refused.
        let paths = transport.sent.map(\.path)
        let lastPrice = transport.sent.lastIndex {
            $0.path == "/v1/subscriptionPrices" || ($0.method == .patch && $0.path == "/v1/subscriptions/\(sub)")
        }
        #expect(lastPrice.map { $0 < (paths.firstIndex(of: IntroductoryOfferEverywhere.path) ?? 0) } == true)
    }

    @Test func aPaidOfferOnAnExistingSubscriptionUsesEachTerritorysEqualizedPoint() async {
        let product = IntroductoryOfferChangeBuilderTests.monthly
        let offer = IntroductoryOfferChangeBuilderTests.paid
        let step = IntroductoryOfferEverywhere(subscriptionID: product.id, offer: offer)
        let transport = FakePushTransport(remote: [
            step.pricePointsPath: Data(#"{"data":[{"id":"u4","attributes":{"customerPrice":"4.99"}},{"id":"u5","attributes":{"customerPrice":"5.99"}}]}"#.utf8),
            IntroductoryOfferEverywhere.equalizationsPath(pricePointID: "u4"): Data(#"{"data":[\#(Self.inTerritory("b4", "BRA")),\#(Self.inTerritory("g4", "GBR"))]}"#.utf8),
        ])
        let change = IntroductoryOfferChangeBuilder(app: Self.app).change(for: offer, subscription: product)
        let controller = await push([change], via: transport)

        #expect(controller.doneCount == 1)
        let sent = transport.sent
        #expect(sent.map { PushPagedRead.relationshipID("territory", of: data($0)) } == ["USA", "BRA"])
        #expect(sent.map { PushPagedRead.relationshipID("subscriptionPricePoint", of: data($0)) } == ["u4", "b4"])
        #expect(sent.allSatisfy { (data($0)["attributes"] as? [String: Any])?["numberOfPeriods"] as? Int == 3 })
        // Chosen territories: the subscription's availability isn't read.
        #expect(!transport.fetched.contains(step.availabilityPath))
    }

    @Test func aPaidOfferAtAPriceAppleDoesntHaveIsNotSent() async throws {
        let product = IntroductoryOfferChangeBuilderTests.monthly
        var offer = IntroductoryOfferChangeBuilderTests.paid
        offer.price = Decimal(string: "4.49")
        let step = IntroductoryOfferEverywhere(subscriptionID: product.id, offer: offer)
        let transport = FakePushTransport(remote: [
            step.pricePointsPath: Data(#"{"data":[{"id":"u4","attributes":{"customerPrice":"3.99"}},{"id":"u5","attributes":{"customerPrice":"4.99"}}]}"#.utf8),
        ])
        await #expect(throws: IntroductoryOfferPushError.self) {
            try await step.send(via: transport, progress: { _, _ in }, note: { _ in })
        }
        #expect(transport.sent.isEmpty)
    }

    @Test func aSubscriptionThatIsntSoldAnywhereGetsNoOffer() async {
        let product = IntroductoryOfferChangeBuilderTests.monthly
        let step = IntroductoryOfferEverywhere(subscriptionID: product.id, offer: NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek))
        let transport = FakePushTransport(remote: [step.availabilityPath: Data(#"{"data":null}"#.utf8)])
        await #expect(throws: IntroductoryOfferPushError.self) {
            try await step.send(via: transport, progress: { _, _ in }, note: { _ in })
        }
        #expect(transport.sent.isEmpty)
    }
}
