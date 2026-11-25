//
//  ExtrasReviewRemovalTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A header or search artwork marked Delete… in Screenshots: one item in
/// Review & Push, pushed as a removal of the page's placements.
@MainActor
@Suite("Extras review: deleted artwork")
struct ExtrasReviewRemovalTests {
    @Test func aDeletionIsAnItemWithItsOwnID() throws {
        var extras = ScreenshotExtras.byHand(at: StoreArtworkFixtures.date)
        extras.markRemoval(.header, locale: "de-DE", at: StoreArtworkFixtures.date)
        let plan = try #require(ExtrasReviewFixtures.plan(extras))
        #expect(plan.items.map(\.id) == ["remove-header-de-DE"])
        let item = try #require(plan.items.first)
        #expect(item.isRemoval)
        #expect(item.kindTitle == "Header deleted")
        #expect(item.localizationID == "loc-de-DE")
        #expect(plan.countTitle == "1 image")
        let push = try #require(item.pushItem)
        #expect(push.kind == .removal(placementTypes: ["PRODUCT_PAGE_HEADER_ASSET"]))
    }

    @Test func aDeletionGoesWithTheRunsFiles() throws {
        var extras = ExtrasReviewFixtures.extras(previews: false)
        extras.markRemoval(.search, locale: "fr-FR", at: StoreArtworkFixtures.date)
        let plan = try #require(ExtrasReviewFixtures.plan(extras))
        #expect(plan.items.contains { $0.id == "remove-search-fr-FR" })
        #expect(!plan.items.contains { $0.id == "search-fr-FR" }, "Delete… dropped the waiting file")
    }
}
#endif
