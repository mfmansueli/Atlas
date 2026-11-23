//
//  NewInAppPurchaseOfferCodeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What New Offer Code… and propose_in_app_purchase_offer_code refuse for
/// an in-app purchase, as App Store Connect would.
@Suite("NewInAppPurchaseOfferCode")
struct NewInAppPurchaseOfferCodeTests {
    private static let price = Decimal(string: "79.99")
    private let today = NewIntroductoryOffer.day(from: "2026-11-23") ?? .now

    private func code(_ price: Decimal? = 0, name: String = "Launch week") -> NewInAppPurchaseOfferCode {
        NewInAppPurchaseOfferCode(name: name, terms: InAppPurchaseOfferTerms(price: price))
    }

    @Test func aFreeCodeEverywhereIsFine() {
        #expect(code().problems(purchasePrice: Self.price, existing: [], today: today).isEmpty)
        #expect(code().terms.pricesTitle == "Free everywhere it runs")
    }

    @Test func aLowerPriceIsFineButNotTheSameOrHigher() {
        #expect(code(Decimal(string: "39.99")).problems(purchasePrice: Self.price, existing: [], today: today).isEmpty)
        #expect(code(Self.price).problems(purchasePrice: Self.price, existing: [], today: today) == [.notBelowPurchasePrice("$79.99")])
        #expect(code(Decimal(string: "1.999")).problems(purchasePrice: Self.price, existing: [], today: today) == [.invalidInAppPurchaseOfferPrice])
        #expect(code(nil).problems(purchasePrice: Self.price, existing: [], today: today) == [.terms(.missingPrice)])
    }

    @Test func aNameIsNeededAndUniqueForThePurchase() {
        let existing = [ExistingInAppPurchaseOfferCode(id: "ioc1", name: "Launch week", eligibilities: [.nonSpender])]
        #expect(code().problems(purchasePrice: Self.price, existing: existing, today: today) == [.inAppPurchaseOfferCodeNameTaken("Launch week")])
        #expect(code().problems(purchasePrice: Self.price, existing: [], takenNames: ["Launch week"], today: today)
            == [.inAppPurchaseOfferCodeNameTaken("Launch week")])
        #expect(code(name: " ").problems(purchasePrice: Self.price, existing: [], today: today).isEmpty == false)
    }

    @Test func someoneMustBeAbleToRedeemIt() {
        var code = code()
        code.eligibilities = []
        #expect(code.problems(purchasePrice: Self.price, existing: [], today: today) == [.noSpenderEligibility])
    }

    @Test func tenActiveCodesIsTheMost() {
        let existing = (1...10).map { ExistingInAppPurchaseOfferCode(id: "ioc\($0)", name: "Code \($0)", eligibilities: [.nonSpender]) }
        #expect(code().problems(purchasePrice: Self.price, existing: existing, today: today)
            == [.tooManyInAppPurchaseOfferCodes(limit: 10)])
        let inactive = existing.map { code in
            var code = code
            code.isActive = false
            return code
        }
        #expect(code().problems(purchasePrice: Self.price, existing: inactive, today: today).isEmpty)
    }

    @Test func aCustomCodeIsUniqueForTheAppAndFollowsAppReview() {
        let existing = [ExistingInAppPurchaseOfferCode(
            id: "ioc1", name: "Other", eligibilities: [.nonSpender],
            customCodes: [ExistingCustomCode(id: "cc1", code: "LUMENLIFE", numberOfCodes: 10)]
        )]
        var code = code()
        code.customCode = NewCustomCode(code: "lumenlife", numberOfCodes: 10)
        #expect(code.problems(purchasePrice: Self.price, existing: existing, today: today).isEmpty == false)
        code.customCode = NewCustomCode(code: "ANDROID", numberOfCodes: 10)
        #expect(code.problems(purchasePrice: Self.price, existing: [], today: today).isEmpty == false)
        code.customCode = NewCustomCode(code: "PODCAST30", numberOfCodes: 10)
        #expect(code.problems(purchasePrice: Self.price, existing: existing, today: today).isEmpty)
    }

    @Test func territoryPricesFollowTheSubscriptionRules() {
        let terms = InAppPurchaseOfferTerms(
            price: Decimal(string: "39.99"), territories: .chosen(["BRA"]), territoryPrices: ["USA": 1, "JPN": 500]
        )
        let problems = terms.problems(purchasePrice: Self.price)
        #expect(problems.contains(.basePriceSetApart))
        #expect(problems.contains(.pricedOutsideTerritories(["JPN"])))
        // A free code sends none.
        #expect(InAppPurchaseOfferTerms(price: 0, territoryPrices: ["BRA": 1]).sentTerritoryPrices.isEmpty)
    }

    @Test func theEligibilitiesAreTheSpecsInItsOrder() {
        #expect(InAppPurchaseOfferCodeEligibility.allCases.map(\.rawValue) == ["NON_SPENDER", "ACTIVE_SPENDER", "CHURNED_SPENDER"])
        #expect(InAppPurchaseOfferCodeEligibility.sorted([.churnedSpender, .nonSpender]) == [.nonSpender, .churnedSpender])
        let attributes = NewInAppPurchaseOfferCode(name: " Week ", eligibilities: [.churnedSpender, .activeSpender], terms: .init(price: 0)).attributes
        #expect(attributes["name"] as? String == "Week")
        #expect(attributes["customerEligibilities"] as? [String] == ["ACTIVE_SPENDER", "CHURNED_SPENDER"])
    }
}
