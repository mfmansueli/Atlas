//
//  NewSubscriptionPricesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A new subscription's prices outside the United States (board 18): the
/// three choices, the recommended prices worked out for its US price, how
/// they ride in the starting price's placeholder to the push, and the
/// subscriptions left to review later.
@MainActor
@Suite("New subscription · recommended prices")
struct NewSubscriptionPricesTests {
    private static let calculator = PriceCalculator(snapshot: PricingSampleData.shared.snapshot, commission: .smallBusiness)

    private static func recommendation(_ price: String = "9.99") throws -> NewSubscriptionRecommendation {
        try #require(NewSubscriptionRecommendation.make(
            basePrice: Decimal(string: price) ?? 0, reference: nil, calculator: calculator, strategy: .recommended
        ))
    }

    // MARK: - The choice

    @Test func threeChoicesWithTheirAssistantNames() {
        #expect(NewSubscriptionPriceChoice.allCases.map(\.rawValue) == ["recommended", "review_later", "equalized"])
        #expect(NewSubscriptionPriceChoice.allCases.filter(\.needsPro) == [.recommended])
        #expect(NewSubscriptionPriceChoice.allCases.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    @Test func onlyTheRecommendedChoiceOverridesPrices() {
        var subscription = NewSubscriptionChangeBuilderTests.monthly()
        subscription.recommendedPrices = ["BRA": Decimal(string: "5.9") ?? 0]
        #expect(subscription.priceOverrides.isEmpty)
        subscription.priceChoice = .reviewLater
        #expect(subscription.priceOverrides.isEmpty)
        subscription.priceChoice = .recommended
        #expect(subscription.priceOverrides == ["BRA": Decimal(string: "5.9") ?? 0])
    }

    // MARK: - The recommendation

    @Test func everyOtherCountryHasAnEqualizedAndARecommendedPrice() throws {
        let recommendation = try Self.recommendation()
        #expect(recommendation.places.count == TerritoryCatalog.standard.territories.count - 1)
        #expect(!recommendation.places.contains { $0.id == "USA" })
        #expect(recommendation.places.allSatisfy { $0.equalized > 0 && $0.recommended > 0 })
        #expect(recommendation.lowerCount + recommendation.higherCount + recommendation.equalizedCount == recommendation.places.count)
        #expect(!recommendation.usesAppleRatios)
    }

    @Test func purchasingPowerLowersPricesInPoorerCountries() throws {
        let recommendation = try Self.recommendation()
        #expect(recommendation.lowerCount > 0)
        let india = try #require(recommendation.places.first { $0.id == "IND" })
        #expect(india.isLower)
        #expect(india.change < 0)
        #expect(india.changeText.hasPrefix("-") || india.changeText.hasPrefix("−"))
    }

    @Test func onlyPricesThatDifferArePushed() throws {
        let recommendation = try Self.recommendation()
        #expect(recommendation.prices.count == recommendation.changed.count)
        for place in recommendation.changed {
            #expect(recommendation.prices[place.id] == place.recommended)
        }
        #expect(!recommendation.summary.isEmpty)
        #expect(!recommendation.samplesText.isEmpty)
    }

    @Test func noPriceNoRecommendation() {
        #expect(NewSubscriptionRecommendation.make(basePrice: 0, reference: nil, calculator: Self.calculator, strategy: .recommended) == nil)
    }

    @Test func aReferenceSubscriptionLendsApplesRatios() throws {
        let estimate = try Self.recommendation()
        let reference = NewSubscriptionRecommendation.priceSheet(
            basePrice: Decimal(string: "4.99") ?? 0, reference: nil, commission: .smallBusiness, catalog: .standard
        )
        let made = try #require(NewSubscriptionRecommendation.make(
            basePrice: Decimal(string: "9.99") ?? 0, reference: reference, calculator: Self.calculator, strategy: .recommended
        ))
        #expect(made.usesAppleRatios)
        #expect(made.places.count == estimate.places.count)
    }

    // MARK: - The push

    @Test func overridesRideInThePlaceholderAndComeBack() throws {
        let overrides = ["IND": Decimal(69), "BRA": Decimal(string: "5.9") ?? 0]
        let request = SubscriptionStartingPrices.request(
            subscriptionID: "sub1", territoryID: "USA", price: Decimal(string: "9.99") ?? 0, overrides: overrides
        )
        let prices = try #require(SubscriptionStartingPrices(request))
        #expect(prices.customerPrice == Decimal(string: "9.99"))
        #expect(prices.overrides == overrides)
        #expect(SubscriptionStartingPrices.placeholder(territoryID: "USA", price: Decimal(string: "9.99") ?? 0, overrides: overrides)
            == "{startingPrice:USA:9.99:BRA=5.9,IND=69}")
    }

    @Test func withoutOverridesThePlaceholderIsUnchanged() throws {
        #expect(SubscriptionStartingPrices.placeholder(territoryID: "USA", price: Decimal(string: "9.99") ?? 0) == "{startingPrice:USA:9.99}")
        let prices = try #require(SubscriptionStartingPrices(
            SubscriptionStartingPrices.request(subscriptionID: "sub1", territoryID: "USA", price: Decimal(string: "9.99") ?? 0)
        ))
        #expect(prices.overrides.isEmpty)
    }

    @Test func theNearestPointWinsTiesGoHigher() {
        let points: [[String: Any]] = [
            ["id": "a", "attributes": ["customerPrice": "4.49"]],
            ["id": "b", "attributes": ["customerPrice": "4.99"]],
            ["id": "c", "attributes": ["customerPrice": "5.49"]],
        ]
        #expect(SubscriptionStartingPrices.nearestPointID(to: Decimal(string: "4.5") ?? 0, in: points) == "a")
        #expect(SubscriptionStartingPrices.nearestPointID(to: Decimal(string: "4.99") ?? 0, in: points) == "b")
        #expect(SubscriptionStartingPrices.nearestPointID(to: Decimal(string: "5.24") ?? 0, in: points) == "c")
        #expect(SubscriptionStartingPrices.nearestPointID(to: 1, in: []) == nil)
    }

    @Test func aRecommendedTerritoryGetsItsOwnPoint() async throws {
        let transport = OverridePricesTransport()
        let prices = try #require(SubscriptionStartingPrices(SubscriptionStartingPrices.request(
            subscriptionID: StartingPricesTransport.subscriptionID, territoryID: "USA", price: Decimal(string: "9.99") ?? 0,
            overrides: ["T001": Decimal(string: "4.5") ?? 0]
        )))
        let refusal = try await prices.send(via: transport, slots: PushSlots(), batches: true) { _, _ in } note: { _ in }
        #expect(refusal == nil)
        #expect(transport.fetched.contains(OverridePricesTransport.pointsPath))
        let body = try #require(transport.base.patches.first?.body)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let included = object["included"] as? [[String: Any]] ?? []
        let pointByTerritory = Dictionary(uniqueKeysWithValues: included.compactMap { resource -> (String, String)? in
            let relationships = resource["relationships"] as? [String: Any]
            func id(_ name: String) -> String? {
                ((relationships?[name] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String
            }
            guard let territory = id("territory"), let point = id("subscriptionPricePoint") else { return nil }
            return (territory, point)
        })
        #expect(pointByTerritory["T001"] == "t1a")
        #expect(pointByTerritory["T002"] == "e2")
        #expect(pointByTerritory["USA"] == "p2")
    }

    @Test func theChangeSaysWhereThePricesAreRecommended() {
        var subscription = NewSubscriptionChangeBuilderTests.monthly()
        subscription.priceChoice = .recommended
        subscription.recommendedPrices = ["BRA": 5, "IND": 69]
        let text = NewSubscriptionChangeBuilder.priceText("$9.99", subscription: subscription)
        #expect(text.contains("recommended in 2 countries and regions"))
        subscription.priceChoice = .equalized
        #expect(NewSubscriptionChangeBuilder.priceText("$9.99", subscription: subscription).contains("equalized everywhere else"))
    }

    // MARK: - Review later

    @Test func reviewLaterIsRememberedPerApp() {
        let store = PricingModeStore(defaults: nil)
        #expect(!store.isReviewingLater(productID: "com.example.weekly", appID: "app1"))
        store.setReviewLater(true, productID: "com.example.weekly", appID: "app1")
        #expect(store.isReviewingLater(productID: "com.example.weekly", appID: "app1"))
        #expect(!store.isReviewingLater(productID: "com.example.weekly", appID: "app2"))
        store.setReviewLater(false, productID: "com.example.weekly", appID: "app1")
        #expect(!store.isReviewingLater(productID: "com.example.weekly", appID: "app1"))
        #expect(store.reviewLaterProductIDs.isEmpty)
    }

    @Test func reviewLaterSurvivesARelaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: "NewSubscriptionPricesTests.\(UUID().uuidString)"))
        PricingModeStore(defaults: defaults).setReviewLater(true, productID: "com.example.weekly", appID: "app1")
        #expect(PricingModeStore(defaults: defaults).isReviewingLater(productID: "com.example.weekly", appID: "app1"))
    }
}
