//
//  OverviewWaitingSectionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Overview's "suggestions to review": one row per section, in the
/// design's order, saying where the suggestions are or that it's reviewed.
@Suite("Overview waiting rows")
struct OverviewWaitingSectionTests {
    @Test func eachSectionSaysWhereItsSuggestionsAre() {
        let facts = OverviewWaitingSection.Facts(
            counts: SectionBadgeCounts([.storePage: 32, .screenshots: 3, .subscriptionPricing: 2, .appInformation: 4]),
            storePageLanguages: 6, newPages: 2, captionLanguages: 1, informationPages: ["Age Rating", "Accessibility"]
        )
        let rows = OverviewWaitingSection.rows(facts)
        #expect(rows.map(\.section) == [.storePage, .screenshots, .subscriptionPricing, .appInformation])
        #expect(rows.map(\.detail) == [
            "Text in 6 languages, including 2 new pages",
            "Captions in 1 language",
            "Prices for 2 products",
            "Age Rating, Accessibility",
        ])
        #expect(rows.map(\.count) == [32, 3, 2, 4])
        #expect(rows[0].buttonTitle == "Review")
        #expect(rows[0].accessibilityText == "Open Store Page, 32 suggestions to review")
    }

    @Test func aSectionWithNothingWaitingIsReviewed() {
        let rows = OverviewWaitingSection.rows(OverviewWaitingSection.Facts(counts: SectionBadgeCounts()))
        #expect(rows.map(\.detail) == ["Every language reviewed", "Every caption reviewed", "Every price reviewed", "Every page reviewed"])
        #expect(rows.allSatisfy { $0.buttonTitle == "Open" })
        #expect(rows[2].accessibilityText == "Open Pricing")
    }

    @Test func singularsAndAPricingEstimate() {
        let facts = OverviewWaitingSection.Facts(
            counts: SectionBadgeCounts([.storePage: 1, .subscriptionPricing: 1]),
            storePageLanguages: 1, newPages: 1, isPricingEstimate: true
        )
        let rows = OverviewWaitingSection.rows(facts)
        #expect(rows[0].detail == "Text in 1 language, including 1 new page")
        #expect(rows[0].accessibilityText == "Open Store Page, 1 suggestion to review")
        #expect(rows[2].detail == "Prices that likely hold people back")
    }

    /// Pricing's count already holds the review screenshots and the
    /// retention wordings (`SectionBadgeCounts.pricingCount`), so the row
    /// shows the sidebar's number and names what's in it.
    @Test func pricingNamesProductsReviewScreenshotsAndRetention() {
        let facts = OverviewWaitingSection.Facts(
            counts: SectionBadgeCounts([.subscriptionPricing: 5]), reviewShots: 1, retentionSuggestions: 2
        )
        let pricing = OverviewWaitingSection.rows(facts)[2]
        // The list's commas follow the person's region.
        #expect(pricing.detail.hasPrefix("Prices for 2 products, 1 review screenshot"))
        #expect(pricing.detail.hasSuffix("and a retention message"))
        #expect(pricing.count == 5)
        let retentionOnly = OverviewWaitingSection.rows(
            OverviewWaitingSection.Facts(counts: SectionBadgeCounts([.subscriptionPricing: 1]), retentionSuggestions: 1)
        )[2]
        #expect(retentionOnly.detail == "A retention message")
        #expect(retentionOnly.count == 1)
        let pricesAndRetention = OverviewWaitingSection.Facts(counts: SectionBadgeCounts([.subscriptionPricing: 3]), retentionSuggestions: 1)
        #expect(OverviewWaitingSection.rows(pricesAndRetention)[2].detail == "Prices for 2 products and a retention message")
    }

    /// The Overview's Pricing row and the sidebar's Pricing badge read the
    /// same count, so the two numbers always agree.
    @Test func pricingsRowShowsTheSidebarsCount() {
        let counts = SectionBadgeCounts([.subscriptionPricing: 4])
        let facts = OverviewWaitingSection.Facts(counts: counts, reviewShots: 1, retentionSuggestions: 1)
        #expect(OverviewWaitingSection.rows(facts)[2].count == counts.count(for: .subscriptionPricing))
    }

    @Test func appInformationCountsComplianceAnswersAndAlwaysSaysWhere() {
        let facts = OverviewWaitingSection.Facts(
            counts: SectionBadgeCounts([.appInformation: 2]), complianceAnswers: 3, informationPages: ["Age Rating", "App Compliance"]
        )
        let row = OverviewWaitingSection.rows(facts)[3]
        #expect(row.count == 5)
        #expect(row.detail == "Age Rating, App Compliance")
        let unnamed = OverviewWaitingSection.rows(OverviewWaitingSection.Facts(counts: SectionBadgeCounts([.appInformation: 7])))[3]
        #expect(unnamed.detail == "7 answers suggested")
    }

    @Test func theListSaysHowManyAreWaiting() {
        #expect(OverviewWaitingSection.title(total: 65) == "65 suggestions to review")
        #expect(OverviewWaitingSection.title(total: 1) == "1 suggestion to review")
        #expect(OverviewWaitingSection.title(total: 0) == "Nothing to review")
    }

    @Test func whatEachSectionChanges() {
        let rows = OverviewWaitingSection.rows(OverviewWaitingSection.Facts(counts: SectionBadgeCounts()))
        #expect(rows[0].what(appName: "Lumen") == "The words on the page and in search")
        #expect(rows[2].what(appName: "Lumen") == "What Lumen costs in each country")
        #expect(rows.map(\.systemImage) == ["doc.text", "iphone", "tag", "info.circle"])
    }
}
