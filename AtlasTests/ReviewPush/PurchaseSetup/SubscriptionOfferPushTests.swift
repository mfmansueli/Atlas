//
//  SubscriptionOfferPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing promotional offers, win-back offers and offer codes: each
/// territory's price point read from the US price and its equalizations
/// (or a price set apart), one create with inline prices, the codes after
/// the offer code they belong to, and reading them back.
@MainActor
@Suite("PushController · subscription offers")
struct SubscriptionOfferPushTests {
    private let queue = ChangeQueue()
    private let history = PushHistory()
    private static let app = NewSubscriptionChangeBuilderTests.app
    private static let monthly = IntroductoryOfferChangeBuilderTests.monthly
    private static let reader = OfferPriceReader(plan: OfferPricesPlan(subscriptionID: "sub1", usPrice: nil, territoryIDs: nil))

    private static func created(_ type: String, _ id: String) -> Data {
        Data(#"{"data":{"type":"\#(type)","id":"\#(id)"}}"#.utf8)
    }

    /// The subscription's points in `territory` at these prices.
    private static func points(_ prices: [(String, String)]) -> Data {
        let items = prices.map { #"{"id":"\#($0.0)","attributes":{"customerPrice":"\#($0.1)"}}"# }
        return Data(#"{"data":[\#(items.joined(separator: ","))]}"#.utf8)
    }

    private func push(_ changes: [PendingChange], via transport: FakePushTransport) async -> PushController {
        let controller = PushController(queue: queue, history: history, transport: transport)
        queue.upsert(contentsOf: changes)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    private func body(_ request: PushRequest) -> [String: Any] {
        PushPagedRead.body(of: request) ?? [:]
    }

    private func included(_ request: PushRequest) -> [[String: Any]] {
        body(request)["included"] as? [[String: Any]] ?? []
    }

    @Test func aPaidPromotionalOfferGetsEqualizedPointsAndOnesSetApart() async {
        let terms = OfferTerms(
            mode: .payUpFront, duration: .threeMonths, price: Decimal(string: "9.99"),
            territories: .chosen(["BRA", "USA", "GBR"]), territoryPrices: ["BRA": Decimal(string: "19.90") ?? 0]
        )
        let offer = NewPromotionalOffer(name: "Three months", identifier: "three_months", terms: terms)
        let transport = FakePushTransport(
            remote: [
                Self.reader.pricePointsPath(territoryID: "USA"): Self.points([("pU1", "8.99"), ("pU2", "9.99")]),
                IntroductoryOfferEverywhere.equalizationsPath(pricePointID: "pU2"): Data("""
                {"data":[{"id":"pG","relationships":{"territory":{"data":{"type":"territories","id":"GBR"}}}},
                {"id":"pB","relationships":{"territory":{"data":{"type":"territories","id":"BRA"}}}}]}
                """.utf8),
                Self.reader.pricePointsPath(territoryID: "BRA"): Self.points([("pB2", "19.90")]),
            ],
            responses: ["/v1/subscriptionPromotionalOffers": Self.created("subscriptionPromotionalOffers", "po9")]
        )
        let change = PromotionalOfferChangeBuilder(app: Self.app).change(for: offer, subscription: Self.monthly)
        let controller = await push([change], via: transport)

        #expect(controller.doneCount == 1)
        #expect(queue.changes.isEmpty)
        let sent = transport.sent
        #expect(sent.map(\.path) == ["/v1/subscriptionPromotionalOffers"])
        let prices = included(sent[0])
        // The United States first, then the chosen order.
        #expect(prices.compactMap { PushPagedRead.relationshipID("territory", of: $0) } == ["USA", "BRA", "GBR"])
        #expect(prices.compactMap { PushPagedRead.relationshipID("subscriptionPricePoint", of: $0) } == ["pU2", "pB2", "pG"])
        #expect(body(sent[0])[OfferPricesPlan.metaKey] == nil)
        // It looked for an offer a push made before.
        #expect(transport.fetched.contains(SubscriptionOfferResource.promotional.identitiesPath(subscriptionID: "sub1")))
    }

    @Test func aPriceAppleDoesntHaveStopsThePush() async {
        let terms = OfferTerms(mode: .payUpFront, duration: .threeMonths, price: Decimal(string: "9.95"), territories: .chosen(["USA"]))
        let transport = FakePushTransport(remote: [
            Self.reader.pricePointsPath(territoryID: "USA"): Self.points([("pU1", "8.99"), ("pU2", "9.99")]),
        ])
        let change = PromotionalOfferChangeBuilder(app: Self.app).change(
            for: NewPromotionalOffer(name: "Odd", identifier: "odd", terms: terms), subscription: Self.monthly
        )
        let controller = await push([change], via: transport)
        #expect(controller.doneCount == 0)
        #expect(queue.changes.count == 1)
        #expect(transport.sent.isEmpty)
        let error = SubscriptionOfferPushError.noPricePoint(territoryID: "USA", price: Decimal(string: "9.95") ?? 0, nearest: [])
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func aFreeWinBackOfferGoesWhereTheSubscriptionIsSold() async {
        let settings = WinBackOfferSettings(startDate: NewIntroductoryOffer.day(from: "2099-01-01") ?? .now)
        let offer = NewWinBackOffer(
            referenceName: "We miss you", offerID: "we_miss_you", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth), settings: settings
        )
        let reader = OfferPriceReader(plan: OfferPricesPlan(subscriptionID: "sub1", usPrice: nil, territoryIDs: nil))
        let transport = FakePushTransport(
            remote: [
                reader.availabilityPath: Data(#"{"data":{"type":"subscriptionAvailabilities","id":"av1"}}"#.utf8),
                IntroductoryOfferEverywhere.availableTerritoriesPath(availabilityID: "av1"): Data(#"{"data":[{"id":"USA"},{"id":"JPN"}]}"#.utf8),
            ],
            responses: ["/v1/winBackOffers": Self.created("winBackOffers", "wb9")]
        )
        let change = WinBackOfferChangeBuilder(app: Self.app).change(for: offer, subscription: Self.monthly)
        let controller = await push([change], via: transport)

        #expect(controller.doneCount == 1)
        let prices = included(transport.sent[0])
        #expect(prices.compactMap { PushPagedRead.relationshipID("territory", of: $0) } == ["USA", "JPN"])
        #expect(prices.allSatisfy { PushPagedRead.relationshipID("subscriptionPricePoint", of: $0) == nil })
        #expect(prices.first?["type"] as? String == "winBackOfferPrices")
    }

    @Test func aPushTriedAgainCarriesOnWithTheOfferItMade() async {
        let settings = WinBackOfferSettings(startDate: NewIntroductoryOffer.day(from: "2099-01-01") ?? .now)
        let offer = NewWinBackOffer(
            referenceName: "We miss you", offerID: "we_miss_you", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth), settings: settings
        )
        let transport = FakePushTransport(remote: [
            SubscriptionOfferResource.winBack.identitiesPath(subscriptionID: "sub1"):
                Data(#"{"data":[{"id":"wb7","attributes":{"offerId":"we_miss_you"}}]}"#.utf8),
        ])
        let change = WinBackOfferChangeBuilder(app: Self.app).change(for: offer, subscription: Self.monthly)
        let controller = await push([change], via: transport)
        #expect(controller.doneCount == 1)
        #expect(transport.sent.isEmpty)
    }

    @Test func anOfferCodesCodesAreMadeForTheOfferCodeItCreated() async {
        var code = NewOfferCode(name: "Podcast", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth, territories: .chosen(["USA"])))
        code.customCode = NewCustomCode(code: "LUMENPOD", numberOfCodes: 100)
        code.oneTimeCodes = NewOneTimeCodes(numberOfCodes: 50, expirationDate: NewIntroductoryOffer.day(from: "2099-01-01") ?? .now)
        let transport = FakePushTransport(responses: [
            "/v1/subscriptionOfferCodes": Self.created("subscriptionOfferCodes", "oc9"),
            NewCustomCode.path: Self.created("subscriptionOfferCodeCustomCodes", "cc9"),
            NewOneTimeCodes.path: Self.created("subscriptionOfferCodeOneTimeUseCodes", "ot9"),
        ])
        let change = OfferCodeChangeBuilder(app: Self.app).change(for: code, subscription: Self.monthly)
        let controller = await push([change], via: transport)

        #expect(controller.doneCount == 1)
        let sent = transport.sent
        #expect(sent.map(\.path) == ["/v1/subscriptionOfferCodes", NewCustomCode.path, NewOneTimeCodes.path])
        for request in sent.dropFirst() {
            let data = body(request)["data"] as? [String: Any] ?? [:]
            #expect(PushPagedRead.relationshipID("offerCode", of: data) == "oc9")
        }
    }

    @Test func newPromotionalPricesReplaceTheOldOnesAfterCheckingThem() async {
        let existing = ExistingPromotionalOffer(
            id: "po1", name: "Come back", identifier: "come_back", mode: .payAsYouGo, duration: .oneMonth, numberOfPeriods: 3,
            prices: ExistingOfferPrices(territoryIDs: ["USA"], usPrice: Decimal(string: "2.99"))
        )
        var terms = existing.terms
        terms.price = Decimal(string: "1.99")
        let change = PromotionalOfferChangeBuilder(app: Self.app).pricesChange(for: existing, terms: terms, subscription: Self.monthly)
        let check = change.conflictCheck?.path ?? ""
        let transport = FakePushTransport(remote: [
            check: Data(#"{"data":[],"included":[{"attributes":{"customerPrice":"2.99"}}]}"#.utf8),
            Self.reader.pricePointsPath(territoryID: "USA"): Self.points([("pU1", "1.99")]),
        ])
        let controller = await push([change], via: transport)
        #expect(controller.doneCount == 1)
        #expect(transport.sent.map(\.method) == [.patch])
        #expect(transport.sent.first?.path == "/v1/subscriptionPromotionalOffers/po1")
        #expect(included(transport.sent[0]).compactMap { PushPagedRead.relationshipID("subscriptionPricePoint", of: $0) } == ["pU1"])
    }

    // MARK: - Reading

    @Test func theOffersAreReadBackWithTheirPricesAndCodes() async throws {
        let transport = FakePushTransport(remote: SubscriptionOfferFixtures.remote(subscriptionID: "sub1"))
        let offers = try await SubscriptionOffersReader(transport: transport).offers(subscriptionID: "sub1")

        let promotional = try #require(offers.promotional.first)
        #expect(promotional.identifier == "come_back")
        #expect(promotional.mode == .payAsYouGo)
        #expect(promotional.numberOfPeriods == 3)
        #expect(promotional.prices.territoryIDs == ["BRA", "USA"])
        #expect(promotional.prices.usPrice == Decimal(string: "2.99"))
        #expect(promotional.prices.customerPrices["BRA"] == Decimal(string: "9.90"))
        #expect(promotional.subscriptionOffer(subscriptionPrice: Decimal(string: "4.99")).kind == .promotional)

        let winBack = try #require(offers.winBack.first)
        #expect(winBack.offerID == "we_miss_you")
        #expect(winBack.settings.eligibility == WinBackEligibility(paidMonths: 2, sinceLastSubscribed: 1...6, waitMonths: 6))
        #expect(winBack.settings.priority == .high)
        #expect(winBack.settings.endDate == nil)
        #expect(winBack.prices.usPrice == nil)

        let code = try #require(offers.codes.first)
        #expect(code.eligibilities == [.new, .expired])
        #expect(code.totalNumberOfCodes == 1500)
        #expect(code.customCodes.map(\.code) == ["LUMENPOD"])
        #expect(code.oneTimeCodes.map(\.numberOfCodes) == [500])
        #expect(code.prices.territoryIDs == ["GBR", "USA"])
        #expect(ExistingOfferCode.customCodes(of: offers.codes) == ["LUMENPOD"])
    }

    @Test func theExtrasSayWhetherTheOffersWereRead() async throws {
        let read = try await PurchaseExtrasReader(transport: FakePushTransport(remote: SubscriptionOfferFixtures.remote(subscriptionID: "sub1")))
            .extras(for: Self.monthly)
        #expect(read.offersRead)
        #expect(read.promotionalOffers.count == 1)
        #expect(read.winBackOffers.count == 1)
        #expect(read.offerCodes.count == 1)
    }
}
