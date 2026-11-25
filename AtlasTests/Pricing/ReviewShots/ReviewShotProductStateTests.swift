//
//  ReviewShotProductStateTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A product's state read back after its review screenshot is uploaded,
/// and why it's still Missing Metadata when Atlas can tell.
@Suite("ReviewShotProductState")
struct ReviewShotProductStateTests {
    @Test func readyToSubmitHasNoCause() {
        let state = ReviewShotProductState(code: "READY_TO_SUBMIT")
        #expect(state.title == "Ready to Submit")
        #expect(state.pillStyle == .neutral)
        #expect(state.cause == nil)
    }

    @Test func missingMetadataNamesWhatAtlasFound() {
        let found = ReviewShotProductState(code: "MISSING_METADATA", gaps: [.prices, .groupLocalization])
        #expect(found.title == "Missing Metadata")
        #expect(found.pillStyle == .warning)
        #expect(found.cause == "Still Missing Metadata: the group’s localization and its prices missing in App Store Connect.")
        let unknown = ReviewShotProductState(code: "MISSING_METADATA")
        #expect(unknown.cause?.contains("Paid Apps agreement") == true, "What Atlas can't read is only named")
    }

    @Test func theReaderAsksForTheGapsOnlyWhileMissingMetadata() async throws {
        let product = PricingProduct(id: "sub1", name: "Monthly", productID: "monthly", isInAppPurchase: false, reviewState: "Approved")
        let ready = FakeProductStateTransport(state: "READY_TO_SUBMIT")
        #expect(try await ReviewShotProductStateReader(transport: ready).state(of: product, groupID: "g1") == ReviewShotProductState(code: "READY_TO_SUBMIT"))
        #expect(ready.paths == ["/v1/subscriptions/sub1?fields%5Bsubscriptions%5D=state"])

        let missing = FakeProductStateTransport(state: "MISSING_METADATA", empty: ["subscriptionGroupLocalizations"], failing: ["/prices"])
        let state = try await ReviewShotProductStateReader(transport: missing).state(of: product, groupID: "g1")
        #expect(state.gaps == [.groupLocalization], "A read that failed says nothing")
        #expect(missing.paths.contains("/v1/subscriptionGroups/g1/subscriptionGroupLocalizations?limit=1"))
    }

    @Test func anInAppPurchaseWithoutAScheduleHasNoPrices() async throws {
        let purchase = PricingProduct(id: "iap1", name: "Lifetime", productID: "life", isInAppPurchase: true, reviewState: "Approved")
        let transport = FakeProductStateTransport(state: "MISSING_METADATA", missing: ["iapPriceSchedule"])
        let state = try await ReviewShotProductStateReader(transport: transport).state(of: purchase, groupID: nil)
        #expect(state.gaps == [.prices])
        #expect(transport.paths.first == "/v2/inAppPurchases/iap1?fields%5BinAppPurchases%5D=state")
        #expect(!transport.paths.contains { $0.contains("subscriptionGroups") }, "An in-app purchase has no group")
    }
}
