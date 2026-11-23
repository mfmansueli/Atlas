//
//  InAppPurchaseOfferCodePushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing an in-app purchase's offer codes: each territory's
/// `inAppPurchasePricePoints` read from the US price and its equalizations
/// (or a price set apart), one create with inline prices, the codes after
/// the offer code they belong to, a retry that finds what a push made
/// before, and reading them back.
@MainActor
@Suite("PushController · in-app purchase offer codes")
struct InAppPurchaseOfferCodePushTests {
    private let queue = ChangeQueue()
    private let history = PushHistory()
    private static let app = NewSubscriptionChangeBuilderTests.app
    private static let lifetime = InAppPurchaseOfferCodeChangeBuilderTests.lifetime
    private static let owner = OfferPriceOwner.inAppPurchase("iap1")
    private static let expiry = NewIntroductoryOffer.day(from: "2099-01-01") ?? .now

    private static func created(_ type: String, _ id: String) -> Data {
        Data(#"{"data":{"type":"\#(type)","id":"\#(id)"}}"#.utf8)
    }

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

    private func data(_ request: PushRequest) -> [String: Any] {
        body(request)["data"] as? [String: Any] ?? [:]
    }

    private func change(_ code: NewInAppPurchaseOfferCode, at date: Date = .now) -> PendingChange {
        InAppPurchaseOfferCodeChangeBuilder(app: Self.app).change(for: code, purchase: Self.lifetime, at: date)
    }

    @Test func aPaidOfferCodeGetsEqualizedPointsAndOnesSetApart() async {
        let terms = InAppPurchaseOfferTerms(
            price: Decimal(string: "9.99"), territories: .chosen(["BRA", "USA", "GBR"]), territoryPrices: ["BRA": Decimal(string: "19.90") ?? 0]
        )
        let code = NewInAppPurchaseOfferCode(name: "Launch week", eligibilities: [.nonSpender, .churnedSpender], terms: terms)
        let transport = FakePushTransport(
            remote: [
                Self.owner.pricePointsPath(territoryID: "USA"): Self.points([("pU1", "8.99"), ("pU2", "9.99")]),
                Self.owner.equalizationsPath(pricePointID: "pU2"): Data("""
                {"data":[{"id":"pG","relationships":{"territory":{"data":{"type":"territories","id":"GBR"}}}},
                {"id":"pB","relationships":{"territory":{"data":{"type":"territories","id":"BRA"}}}}]}
                """.utf8),
                Self.owner.pricePointsPath(territoryID: "BRA"): Self.points([("pB2", "19.90")]),
            ],
            responses: [InAppPurchaseOfferCodeResource.offerCodesPath: Self.created("inAppPurchaseOfferCodes", "ioc9")]
        )
        let controller = await push([change(code)], via: transport)

        #expect(controller.doneCount == 1)
        #expect(queue.changes.isEmpty)
        let sent = transport.sent
        #expect(sent.map(\.path) == [InAppPurchaseOfferCodeResource.offerCodesPath])
        let sentData = data(sent[0])
        let attributes = sentData["attributes"] as? [String: Any] ?? [:]
        #expect(attributes["name"] as? String == "Launch week")
        #expect(attributes["customerEligibilities"] as? [String] == ["NON_SPENDER", "CHURNED_SPENDER"])
        // Only what the spec's create takes: no mode, duration or periods.
        #expect(Set(attributes.keys) == ["name", "customerEligibilities"])
        #expect(PushPagedRead.relationshipID("inAppPurchase", of: sentData) == "iap1")
        let prices = body(sent[0])["included"] as? [[String: Any]] ?? []
        #expect(prices.compactMap { PushPagedRead.relationshipID("territory", of: $0) } == ["USA", "BRA", "GBR"])
        #expect(prices.compactMap { PushPagedRead.relationshipID("pricePoint", of: $0) } == ["pU2", "pB2", "pG"])
        #expect(prices.allSatisfy { $0["type"] as? String == "inAppPurchaseOfferPrices" })
        let point = (prices.first?["relationships"] as? [String: Any])?["pricePoint"] as? [String: Any]
        #expect((point?["data"] as? [String: Any])?["type"] as? String == "inAppPurchasePricePoints")
        #expect(body(sent[0])[OfferPricesPlan.metaKey] == nil)
        #expect(transport.fetched.contains(InAppPurchaseOfferCodeResource.identitiesPath(purchaseID: "iap1")))
    }

    @Test func aFreeOfferCodeGoesWhereThePurchaseIsSoldAtItsFreePoint() async {
        let code = NewInAppPurchaseOfferCode(name: "Press", terms: InAppPurchaseOfferTerms(price: 0))
        let transport = FakePushTransport(
            remote: [
                Self.owner.availabilityPath: Data(#"{"data":{"type":"inAppPurchaseAvailabilities","id":"av1"}}"#.utf8),
                Self.owner.availableTerritoriesPath(availabilityID: "av1"): Data(#"{"data":[{"id":"USA"},{"id":"JPN"}]}"#.utf8),
                Self.owner.pricePointsPath(territoryID: "USA"): Self.points([("p0", "0.0"), ("p1", "0.99")]),
                Self.owner.equalizationsPath(pricePointID: "p0"): Data("""
                {"data":[{"id":"j0","relationships":{"territory":{"data":{"type":"territories","id":"JPN"}}}}]}
                """.utf8),
            ],
            responses: [InAppPurchaseOfferCodeResource.offerCodesPath: Self.created("inAppPurchaseOfferCodes", "ioc1")]
        )
        let controller = await push([change(code)], via: transport)
        #expect(controller.doneCount == 1)
        let prices = body(transport.sent[0])["included"] as? [[String: Any]] ?? []
        #expect(prices.compactMap { PushPagedRead.relationshipID("pricePoint", of: $0) } == ["p0", "j0"])
        #expect(Self.owner.availabilityPath == "/v2/inAppPurchases/iap1/inAppPurchaseAvailability")
    }

    @Test func aPriceAppleDoesntHaveStopsThePush() async {
        let code = NewInAppPurchaseOfferCode(name: "Odd", terms: InAppPurchaseOfferTerms(price: Decimal(string: "9.95"), territories: .chosen(["USA"])))
        let transport = FakePushTransport(remote: [
            Self.owner.pricePointsPath(territoryID: "USA"): Self.points([("pU1", "8.99"), ("pU2", "9.99")]),
        ])
        let controller = await push([change(code)], via: transport)
        #expect(controller.doneCount == 0)
        #expect(queue.changes.count == 1)
        #expect(transport.sent.isEmpty)
        let error = Self.owner.noPricePoint(territoryID: "USA", price: Decimal(string: "9.95") ?? 0, nearest: [])
        #expect(error.errorDescription?.contains("in-app purchase") == true)
    }

    @Test func theCodesAreMadeForTheOfferCodeItCreated() async {
        var code = NewInAppPurchaseOfferCode(name: "Podcast", terms: InAppPurchaseOfferTerms(price: 0, territories: .chosen(["USA"])))
        code.customCode = NewCustomCode(code: "LUMENLIFE", numberOfCodes: 100)
        code.oneTimeCodes = NewOneTimeCodes(numberOfCodes: 50, expirationDate: Self.expiry)
        let transport = FakePushTransport(
            remote: [Self.owner.pricePointsPath(territoryID: "USA"): Self.points([("p0", "0")])],
            responses: [
                InAppPurchaseOfferCodeResource.offerCodesPath: Self.created("inAppPurchaseOfferCodes", "ioc7"),
                InAppPurchaseOfferCodeResource.customCodesPath: Self.created("inAppPurchaseOfferCodeCustomCodes", "cc7"),
                InAppPurchaseOfferCodeResource.oneTimeCodesPath: Self.created("inAppPurchaseOfferCodeOneTimeUseCodes", "ot7"),
            ]
        )
        let controller = await push([change(code)], via: transport)

        #expect(controller.doneCount == 1)
        let sent = transport.sent
        #expect(sent.map(\.path) == [
            InAppPurchaseOfferCodeResource.offerCodesPath, InAppPurchaseOfferCodeResource.customCodesPath,
            InAppPurchaseOfferCodeResource.oneTimeCodesPath,
        ])
        #expect(PushPagedRead.relationshipID("offerCode", of: data(sent[1])) == "ioc7")
        #expect(PushPagedRead.relationshipID("offerCode", of: data(sent[2])) == "ioc7")
        let custom = data(sent[1])["attributes"] as? [String: Any] ?? [:]
        #expect(custom["customCode"] as? String == "LUMENLIFE")
        #expect(custom["numberOfCodes"] as? Int == 100)
        let batch = data(sent[2])["attributes"] as? [String: Any] ?? [:]
        #expect(batch["numberOfCodes"] as? Int == 50)
        #expect(batch["expirationDate"] as? String == "2099-01-01")
        #expect(batch["environment"] as? String == "PRODUCTION")
        // Atlas's own note on when it was queued stays home.
        #expect(body(sent[2])[InAppPurchaseOneTimeCodesCreate.metaKey] == nil)
        // The relationships point at the in-app purchase's offer code type.
        let related = (data(sent[1])["relationships"] as? [String: Any])?["offerCode"] as? [String: Any]
        #expect((related?["data"] as? [String: Any])?["type"] as? String == "inAppPurchaseOfferCodes")
    }

    @Test func aRetryFindsTheOfferCodeItsCustomCodeAndItsBatch() async {
        let queuedAt = Date(timeIntervalSince1970: 1_900_000_000)
        var code = NewInAppPurchaseOfferCode(name: "Podcast", terms: InAppPurchaseOfferTerms(price: 0, territories: .chosen(["USA"])))
        code.customCode = NewCustomCode(code: "lumenlife", numberOfCodes: 100)
        code.oneTimeCodes = NewOneTimeCodes(numberOfCodes: 50, expirationDate: Self.expiry)
        let madeAfter = AppStoreConnectDate.text(queuedAt.addingTimeInterval(120))
        let transport = FakePushTransport(remote: [
            InAppPurchaseOfferCodeResource.identitiesPath(purchaseID: "iap1"):
                Data(#"{"data":[{"id":"ioc3","attributes":{"name":"Other"}},{"id":"ioc4","attributes":{"name":"Podcast"}}]}"#.utf8),
            InAppPurchaseOfferCodeResource.customCodesListPath(offerCodeID: "ioc4"):
                Data(#"{"data":[{"id":"cc4","attributes":{"customCode":"LUMENLIFE","numberOfCodes":100,"active":true}}]}"#.utf8),
            InAppPurchaseOfferCodeResource.oneTimeCodesListPath(offerCodeID: "ioc4"): Data("""
            {"data":[{"id":"ot4","attributes":{"numberOfCodes":50,"expirationDate":"2099-01-01","createdDate":"\(madeAfter)",\
            "environment":"PRODUCTION","active":true}}]}
            """.utf8),
        ])
        let controller = await push([change(code, at: queuedAt)], via: transport)
        #expect(controller.doneCount == 1)
        #expect(transport.sent.isEmpty)
    }

    @Test func aBatchMadeBeforeItWasQueuedIsntTakenForIt() async {
        let queuedAt = Date(timeIntervalSince1970: 1_900_000_000)
        let existing = ExistingInAppPurchaseOfferCode(id: "ioc4", name: "Podcast", eligibilities: [.nonSpender])
        let batch = NewOneTimeCodes(numberOfCodes: 50, expirationDate: Self.expiry)
        let madeBefore = AppStoreConnectDate.text(queuedAt.addingTimeInterval(-86400))
        let transport = FakePushTransport(
            remote: [
                InAppPurchaseOfferCodeResource.oneTimeCodesListPath(offerCodeID: "ioc4"): Data("""
                {"data":[{"id":"ot1","attributes":{"numberOfCodes":50,"expirationDate":"2099-01-01","createdDate":"\(madeBefore)",\
                "environment":"PRODUCTION","active":true}}]}
                """.utf8),
            ],
            responses: [InAppPurchaseOfferCodeResource.oneTimeCodesPath: Self.created("inAppPurchaseOfferCodeOneTimeUseCodes", "ot9")]
        )
        let change = InAppPurchaseOfferCodeChangeBuilder(app: Self.app).oneTimeCodesChange(batch, for: existing, purchase: Self.lifetime, at: queuedAt)
        let controller = await push([change], via: transport)
        #expect(controller.doneCount == 1)
        #expect(transport.sent.map(\.path) == [InAppPurchaseOfferCodeResource.oneTimeCodesPath])
        #expect(PushPagedRead.relationshipID("offerCode", of: data(transport.sent[0])) == "ioc4")
    }

    @Test func aDeactivationTurnsOffTheCustomCodeOnItsOwnPath() async {
        let custom = ExistingCustomCode(id: "cc4", code: "LUMENLIFE", numberOfCodes: 100, expirationDate: nil)
        let existing = ExistingInAppPurchaseOfferCode(id: "ioc4", name: "Podcast", eligibilities: [.nonSpender], customCodes: [custom])
        let path = "/v1/inAppPurchaseOfferCodeCustomCodes/cc4"
        let transport = FakePushTransport(remote: [path: Data(#"{"data":{"id":"cc4","attributes":{"active":true}}}"#.utf8)])
        let change = InAppPurchaseOfferCodeChangeBuilder(app: Self.app).deactivation(of: .customCode(custom), in: existing, purchase: Self.lifetime)
        let controller = await push([change], via: transport)
        #expect(controller.doneCount == 1)
        #expect(transport.sent.map(\.path) == [path])
        #expect(transport.sent.first?.method == .patch)
        #expect(data(transport.sent[0])["type"] as? String == "inAppPurchaseOfferCodeCustomCodes")
        #expect((data(transport.sent[0])["attributes"] as? [String: Any])?["active"] as? Bool == false)
    }

    @Test func theReaderReadsOfferCodesWithPricesAndCodes() async throws {
        let transport = FakePushTransport(remote: [
            InAppPurchaseOfferCodeResource.listPath(purchaseID: "iap1"): Data("""
            {"data":[{"type":"inAppPurchaseOfferCodes","id":"ioc1","attributes":{"name":"Launch week",\
            "customerEligibilities":["CHURNED_SPENDER","NON_SPENDER"],"productionCodeCount":1500,"sandboxCodeCount":20,"active":true}}]}
            """.utf8),
            InAppPurchaseOfferCodeResource.pricesPath(offerCodeID: "ioc1"): Data("""
            {"data":[{"id":"pr1","relationships":{"territory":{"data":{"type":"territories","id":"USA"}},\
            "pricePoint":{"data":{"type":"inAppPurchasePricePoints","id":"pp1"}}}},\
            {"id":"pr2","relationships":{"territory":{"data":{"type":"territories","id":"BRA"}},\
            "pricePoint":{"data":{"type":"inAppPurchasePricePoints","id":"pp2"}}}}],
            "included":[{"type":"inAppPurchasePricePoints","id":"pp1","attributes":{"customerPrice":"39.99"}},
            {"type":"inAppPurchasePricePoints","id":"pp2","attributes":{"customerPrice":"199.90"}}]}
            """.utf8),
            InAppPurchaseOfferCodeResource.customCodesListPath(offerCodeID: "ioc1"):
                Data(#"{"data":[{"id":"cc1","attributes":{"customCode":"LUMENLIFE","numberOfCodes":2000,"expirationDate":"2026-12-31","active":true}}]}"#.utf8),
            InAppPurchaseOfferCodeResource.oneTimeCodesListPath(offerCodeID: "ioc1"): Data("""
            {"data":[{"id":"ot1","attributes":{"numberOfCodes":300,"expirationDate":"2027-03-31","createdDate":"2026-11-02T10:00:00Z",\
            "environment":"SANDBOX","active":false}}]}
            """.utf8),
        ])
        let codes = try await InAppPurchaseOfferCodesReader(transport: transport).offerCodes(purchaseID: "iap1")
        let code = try #require(codes.first)
        #expect(code.name == "Launch week")
        #expect(code.eligibilities == [.nonSpender, .churnedSpender])
        #expect(code.productionCodeCount == 1500)
        #expect(code.sandboxCodeCount == 20)
        #expect(code.prices.usPrice == Decimal(string: "39.99"))
        #expect(code.prices.customerPrices["BRA"] == Decimal(string: "199.90"))
        #expect(Set(code.prices.territoryIDs) == ["USA", "BRA"])
        #expect(code.customCodes.map(\.code) == ["LUMENLIFE"])
        #expect(code.oneTimeCodes.first?.environment == .sandbox)
        #expect(code.oneTimeCodes.first?.isActive == false)
    }

    @Test func theExtrasReaderReadsAnInAppPurchasesOfferCodes() async throws {
        let transport = FakePushTransport(remote: [
            InAppPurchaseOfferCodeResource.listPath(purchaseID: "iap1"):
                Data(#"{"data":[{"type":"inAppPurchaseOfferCodes","id":"ioc1","attributes":{"name":"Launch week","active":true}}]}"#.utf8),
        ])
        let extras = try await PurchaseExtrasReader(transport: transport).extras(for: Self.lifetime)
        #expect(extras.offersRead)
        #expect(extras.inAppPurchaseOfferCodes.map(\.id) == ["ioc1"])
        #expect(extras.offerCodes.isEmpty)
    }
}
