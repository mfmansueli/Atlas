//
//  PricingPreviewInPriceTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// One product in "Preview in": the price people pay in the chosen country,
/// the old price struck through with Suggested or Not pushed while it's
/// changing, and about what it is in US dollars.
@Suite("Preview in price")
struct PricingPreviewInPriceTests {
    private func product(period: SubscriptionPeriod? = .oneYear, isInAppPurchase: Bool = false) -> PricingProduct {
        PricingProduct(
            id: "6450100002", name: "Lumen Plus Annual", productID: "lumen.plus.annual", period: period,
            isInAppPurchase: isInAppPurchase, inAppPurchaseType: isInAppPurchase ? "Non-consumable" : nil, reviewState: "Approved"
        )
    }

    @Test func anOpenSuggestionShowsTheNewPriceAndTheOldOneStruckThrough() {
        let price = PricingProductCard.TerritoryPrice(now: "R$ 249,90", next: "R$ 129,90", isQueued: false, dollars: Decimal(string: "23.6"))
        let row = PricingPreviewInPrice.make(product: product(), price: price)
        #expect(row.id == "6450100002")
        #expect(row.price == "R$ 129,90")
        #expect(row.oldPrice == "R$ 249,90")
        #expect(row.tag == .suggested)
        #expect(row.tag?.title == "Suggested")
        #expect(row.isChanging)
        #expect(row.dollarsText == "≈ $24 per year")
        #expect(row.accessibilityText == "Lumen Plus Annual, R$ 129,90 per year, about $24. Suggested, was R$ 249,90.")
    }

    @Test func aChangeInReviewAndPushIsNotPushed() {
        let price = PricingProductCard.TerritoryPrice(now: "R$ 249,90", next: "R$ 149,90", isQueued: true, dollars: 27)
        let row = PricingPreviewInPrice.make(product: product(), price: price)
        #expect(row.price == "R$ 149,90")
        #expect(row.oldPrice == "R$ 249,90")
        #expect(row.tag == .notPushed)
        #expect(row.tag?.title == "Not pushed")
    }

    @Test func aPriceThatStaysShowsNoTag() {
        let price = PricingProductCard.TerritoryPrice(now: "$4.99", next: nil, dollars: Decimal(string: "4.99"))
        let row = PricingPreviewInPrice.make(product: product(period: .oneMonth), price: price)
        #expect(row.price == "$4.99")
        #expect(row.oldPrice == nil)
        #expect(row.tag == nil)
        #expect(!row.isChanging)
        #expect(row.dollarsText == "≈ $4.99 per month", "cents under $10")
    }

    @Test func withoutARateThereAreNoDollars() {
        let price = PricingProductCard.TerritoryPrice(now: "1.000 Kz", next: nil, dollars: nil)
        let row = PricingPreviewInPrice.make(product: product(), price: price)
        #expect(row.dollarsText == nil)
        #expect(row.accessibilityText == "Lumen Plus Annual, 1.000 Kz per year.")
    }

    @Test(arguments: [
        (SubscriptionPeriod.oneWeek, "per week"),
        (.oneMonth, "per month"),
        (.twoMonths, "every 2 months"),
        (.threeMonths, "every 3 months"),
        (.sixMonths, "every 6 months"),
        (.oneYear, "per year"),
    ])
    func subscriptionsSayHowOftenPeoplePay(period: SubscriptionPeriod, expected: String) {
        #expect(PricingPreviewInPrice.periodText(for: product(period: period)) == expected)
    }

    @Test func inAppPurchasesArePaidOnce() {
        #expect(PricingPreviewInPrice.periodText(for: product(period: nil, isInAppPurchase: true)) == "once")
        #expect(PricingPreviewInPrice.periodText(for: product(period: nil)) == nil)
    }

    @Test func dollarsAreWholeFromTenUp() {
        #expect(PricingPreviewInPrice.dollarsText(Decimal(string: "45.6") ?? 0) == "$46")
        #expect(PricingPreviewInPrice.dollarsText(10) == "$10")
        #expect(PricingPreviewInPrice.dollarsText(Decimal(string: "9.994") ?? 0) == "$9.99")
    }
}
