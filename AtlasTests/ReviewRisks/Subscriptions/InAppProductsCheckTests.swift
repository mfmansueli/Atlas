//
//  InAppProductsCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// 2.1(b): products App Review can't see or take.
@Suite("Review risks · In-app purchases for review")
struct InAppProductsCheckTests {
    typealias Fixtures = ProductRiskFixtures

    private let check = InAppProductsCheck()

    @Test func withoutProductsItSaysItCouldntCheck() {
        guard case .notChecked = check.run(ReviewRiskFacts(appID: "1", appName: "Lumen")) else {
            Issue.record("expected notChecked")
            return
        }
    }

    @Test func approvedProductsHaveNothingToFix() {
        let facts = Fixtures.facts([Fixtures.annual(), Fixtures.lifetime()], preparedVersion: "1.4")
        #expect(check.run(facts) == .clear)
    }

    @Test func missingMetadataBlocksReviewAndNamesTheProduct() throws {
        let facts = Fixtures.facts([Fixtures.annual(state: "MISSING_METADATA")])
        let risk = try #require(Fixtures.risk(check.run(facts), "inAppProducts:missingMetadata"))
        #expect(risk.level == .blocksReview)
        #expect(risk.title.contains("Annual"))
        #expect(risk.evidence.first?.place.contains("Annual") == true)
        #expect(risk.evidence.first?.excerpt.contains("lumen.plus.annual") == true)
        #expect(risk.why.count <= 110)
    }

    @Test func aMissingReviewScreenshotBlocksReview() throws {
        let facts = Fixtures.facts([Fixtures.annual(state: "READY_TO_SUBMIT", screenshot: false), Fixtures.monthly()])
        let risk = try #require(Fixtures.risk(check.run(facts), "inAppProducts:reviewScreenshot"))
        #expect(risk.level == .blocksReview)
        #expect(risk.fix.tool == "propose_purchase_review_screenshot")
        #expect(risk.fix.arguments["productId"] == "lumen.plus.annual")
    }

    /// False positive guard: a screenshot Atlas didn't read, or one an
    /// approved product doesn't need, isn't a risk.
    @Test func anUnreadOrUnneededScreenshotIsNoRisk() {
        let facts = Fixtures.facts([Fixtures.annual(state: "READY_TO_SUBMIT", screenshot: nil), Fixtures.monthly(state: "APPROVED", screenshot: false)])
        #expect(!Fixtures.ids(check.run(facts)).contains("inAppProducts:reviewScreenshot"))
    }

    @Test func aFirstSubscriptionNotSubmittedWithTheVersionBlocksReview() throws {
        let facts = Fixtures.facts([Fixtures.annual(state: "READY_TO_SUBMIT", screenshot: true)], preparedVersion: "1.4")
        let risk = try #require(Fixtures.risk(check.run(facts), "inAppProducts:notSubmitted"))
        #expect(risk.level == .blocksReview)
        #expect(risk.title.contains("1.4"))
        #expect(risk.howSure == .fairlySure)
    }

    @Test func aLaterSubscriptionNotSubmittedIsLikely() throws {
        let facts = Fixtures.facts([Fixtures.annual(state: "READY_TO_SUBMIT", screenshot: true), Fixtures.monthly()], preparedVersion: "1.4")
        let risk = try #require(Fixtures.risk(check.run(facts), "inAppProducts:notSubmitted"))
        #expect(risk.level == .likely)
    }

    /// An approved subscription doesn't make an in-app purchase any less
    /// the first of its kind.
    @Test func aFirstInAppPurchaseBesideApprovedSubscriptionsBlocksReview() throws {
        let facts = Fixtures.facts([Fixtures.annual(), Fixtures.lifetime(state: "READY_TO_SUBMIT", screenshot: true)], preparedVersion: "2.0")
        let risk = try #require(Fixtures.risk(check.run(facts), "inAppProducts:notSubmitted"))
        #expect(risk.level == .blocksReview)
    }

    @Test func readyToSubmitWithoutAVersionBeingPreparedIsNoRisk() {
        let facts = Fixtures.facts([Fixtures.annual(state: "READY_TO_SUBMIT", screenshot: true)])
        #expect(check.run(facts) == .clear)
    }

    @Test func productsSentBackBlockReview() throws {
        let facts = Fixtures.facts([Fixtures.annual(state: "REJECTED"), Fixtures.lifetime(state: "DEVELOPER_ACTION_NEEDED")])
        let risk = try #require(Fixtures.risk(check.run(facts), "inAppProducts:sentBack"))
        #expect(risk.level == .blocksReview)
        #expect(risk.evidence.count == 2)
        #expect(risk.title.contains("2"))
    }

    @Test func removedProductsAreLeftOut() {
        let facts = Fixtures.facts([Fixtures.annual(state: "REMOVED_FROM_SALE", screenshot: false)], preparedVersion: "1.4")
        #expect(check.run(facts) == .clear)
    }

    // MARK: - Facts

    @MainActor
    @Test func statesComeFromInAppTextsElsePricingsWords() {
        let catalog = PricingCatalog(groups: [
            PricingProductGroup(id: "g1", name: "Lumen Plus", isInAppPurchases: false, products: [
                PricingProduct(id: "s1", name: "Annual", productID: "lumen.plus.annual", period: .oneYear, isInAppPurchase: false, reviewState: "Approved"),
            ]),
            PricingProductGroup(id: "inAppPurchases", name: "In-App Purchases", isInAppPurchases: true, products: [
                PricingProduct(
                    id: "p1", name: "Lifetime", productID: "lumen.lifetime", isInAppPurchase: true,
                    reviewState: LivePricingMapper.stateTitle("READY_TO_SUBMIT")
                ),
            ]),
        ])
        var texts = InAppTextsContent.empty
        texts.productStates = ["lumen.plus.annual": "MISSING_METADATA"]
        let facts = ReviewRiskFactsLoader.productFacts(catalog: catalog, inAppTexts: texts, storePage: nil)
        #expect(facts.products.map(\.state) == ["MISSING_METADATA", "READY_TO_SUBMIT"])
        #expect(facts.products.map(\.isSubscription) == [true, false])
        #expect(facts.preparedVersion == nil)
    }

    @Test func aProductIsFirstOfItsKindUntilOneIsApproved() {
        let facts = ReviewRiskProductFacts(products: [ProductRiskFixtures.annual(state: "READY_TO_SUBMIT"), ProductRiskFixtures.lifetime()])
        #expect(facts.isFirst(ProductRiskFixtures.annual(state: "READY_TO_SUBMIT")))
        #expect(!facts.isFirst(ProductRiskFixtures.lifetime(state: "READY_TO_SUBMIT")))
    }
}
