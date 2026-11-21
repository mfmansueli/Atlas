//
//  InAppReviewNoteReadingTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// App Store Connect's `reviewNote` and `state` on `inAppPurchases` and
/// `subscriptions`, kept per product (not per locale).
@Suite("Reading Review Notes")
struct InAppReviewNoteReadingTests {
    @Test func purchasesAndSubscriptionsDecodeTheirNotes() throws {
        let purchase = try JSONDecoder().decode(AppStoreConnectResource<InAppPurchaseAttributes>.self, from: Data("""
        {"type":"inAppPurchases","id":"iap1","attributes":{"name":"Complete","productId":"com.SimProps.complete",
         "state":"APPROVED","reviewNote":"Unlocks the MCP tools."}}
        """.utf8))
        #expect(purchase.attributes.reviewNote == "Unlocks the MCP tools.")
        let subscription = try JSONDecoder().decode(AppStoreConnectResource<SubscriptionAttributes>.self, from: Data("""
        {"type":"subscriptions","id":"sub1","attributes":{"name":"Monthly","productId":"m","state":"READY_TO_SUBMIT","reviewNote":null}}
        """.utf8))
        #expect(subscription.attributes.reviewNote == nil)
    }

    @Test func notesAreKeptPerProduct() {
        var content = InAppTextsContent.empty
        let product = InAppTextProduct(id: "com.SimProps.complete", referenceName: "Complete", kind: .inAppPurchase)
        content.note(product, reviewNote: "Unlocks the MCP tools.", state: "APPROVED")
        content.note(InAppTextProduct(id: "m", referenceName: "Monthly", kind: .subscription), reviewNote: "", state: "READY_TO_SUBMIT")
        #expect(content.reviewNotes == ["com.SimProps.complete": "Unlocks the MCP tools."])
        #expect(content.productStates == ["com.SimProps.complete": "APPROVED", "m": "READY_TO_SUBMIT"])
        #expect(content.texts.isEmpty)
    }
}
