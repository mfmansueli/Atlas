//
//  PricingProductFactsReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Details tab's reads: Family Sharing from the product, availability
/// from its availability's territories. Read-only.
@MainActor
@Suite("Pricing product facts reader")
struct PricingProductFactsReaderTests {
    private let subscription = PricingProduct(
        id: "sub1", name: "Annual", productID: "app.annual", period: .oneYear, isInAppPurchase: false, reviewState: "Approved"
    )
    private let purchase = PricingProduct(
        id: "iap1", name: "Lifetime", productID: "app.lifetime", isInAppPurchase: true, inAppPurchaseType: "Non-consumable", reviewState: "Approved"
    )

    private func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    @Test func aSubscriptionsFactsComeFromItsAvailability() async throws {
        let owner = OfferPriceOwner.subscription("sub1")
        let transport = FakePushTransport(remote: [
            PricingProductFactsReader.productPath(for: subscription): json(["data": ["id": "sub1", "attributes": ["familySharable": true]]]),
            owner.availabilityPath: json(["data": ["id": "av1", "attributes": ["availableInNewTerritories": true]]]),
            owner.availableTerritoriesPath(availabilityID: "av1"): json(["data": [["id": "USA"], ["id": "BRA"], ["id": "JPN"]]]),
        ])
        let facts = try await PricingProductFactsReader(transport: transport).facts(for: subscription)
        #expect(facts.isFamilySharable == true)
        #expect(facts.availableInNewTerritories == true)
        #expect(facts.availableTerritoryCount == 3)
        #expect(transport.sent.isEmpty)
        #expect(PricingProductFactsReader.productPath(for: subscription) == "/v1/subscriptions/sub1?fields%5Bsubscriptions%5D=familySharable")
    }

    @Test func anInAppPurchaseWithoutAvailabilityIsSoldNowhere() async throws {
        let transport = FakePushTransport(remote: [
            PricingProductFactsReader.productPath(for: purchase): json(["data": ["id": "iap1", "attributes": ["familySharable": false]]]),
        ])
        let facts = try await PricingProductFactsReader(transport: transport).facts(for: purchase)
        #expect(facts.isFamilySharable == false)
        #expect(facts.availableTerritoryCount == 0)
        #expect(PricingProductFactsReader.productPath(for: purchase) == "/v2/inAppPurchases/iap1?fields%5BinAppPurchases%5D=familySharable")
        #expect(transport.fetched.contains(OfferPriceOwner.inAppPurchase("iap1").availabilityPath))
    }
}
