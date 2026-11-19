//
//  SectionBadgeCountsTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The counts beside the sections in the sidebar: which sections have
/// one, the cap, and what VoiceOver hears.
@MainActor
@Suite("SectionBadgeCounts")
struct SectionBadgeCountsTests {
    @Test func aSectionWithoutSuggestionsHasNoBadge() {
        let counts = SectionBadgeCounts([.storePage: 0])
        #expect(counts.text(for: .storePage) == nil)
        #expect(counts.text(for: .overview) == nil)
    }

    @Test func theTextStopsAt99ButVoiceOverHearsTheExactCount() {
        let counts = SectionBadgeCounts([.storePage: 99, .appInformation: 100])
        #expect(counts.text(for: .storePage) == "99")
        #expect(counts.text(for: .appInformation) == "99+")
        #expect(counts.accessibilitySummary == "Store Page, 99 suggestions to review. App Information, 100 suggestions to review")
    }

    @Test func oneSuggestionIsSingular() {
        #expect(SectionBadgeCounts([.storePage: 1]).accessibilitySummary == "Store Page, 1 suggestion to review")
    }

    @Test func noSuggestionsIsSaidSo() {
        #expect(SectionBadgeCounts().accessibilitySummary == "No suggestions to review")
    }

    @Test func eachAreaCountsTowardItsOwnSectionForThatAppOnly() {
        let store = FieldSuggestionStore()
        let claude = SuggestionSource.assistant(client: "Claude Code")
        store.add(appID: "1", target: .storePage(.englishUS, .whatsNew), value: "a", reason: "", source: claude)
        store.add(appID: "1", target: .storePage(.german, .whatsNew), value: "b", reason: "", source: claude)
        store.add(appID: "1", target: .appInformation(.copyright), value: "c", reason: "", source: claude)
        store.add(appID: "2", target: .storePage(.englishUS, .whatsNew), value: "d", reason: "", source: claude)

        let counts = SectionBadgeCounts(appID: "1", suggestions: store)
        #expect(counts.count(for: .storePage) == 2)
        #expect(counts.count(for: .appInformation) == 1)
        #expect(counts.count(for: .subscriptionPricing) == 0)
    }

    /// App Compliance's suggested answers count toward App Information,
    /// and suggested product pages toward Product Pages.
    @Test func complianceAnswersAndProductPagesCountTowardTheirSections() {
        let extras = SectionBadgeCounts.Extras(complianceAnswers: 3, productPages: 2)
        let counts = SectionBadgeCounts(appID: "1", suggestions: FieldSuggestionStore(), extras: extras)
        #expect(counts.count(for: .appInformation) == 3)
        #expect(counts.count(for: .productPages) == 2)
    }

    #if DEBUG
    /// Before App Information is opened, its count is the suggestions kept
    /// on this Mac.
    @Test func complianceCountsTheKeptSuggestionsBeforeTheSectionReads() {
        let notes = InMemoryAppInformationNotesStore()
        var kept = notes.notes(for: "1")
        kept.complianceSuggestions = DebugAppInformationContent.complianceSuggestions
        notes.setNotes(kept, for: "1")
        let count = SectionBadgeCounts.complianceCount(appID: "1", model: nil, notes: notes)
        #expect(count == DebugAppInformationContent.complianceSuggestions.count)
        #expect(SectionBadgeCounts.complianceCount(appID: "2", model: nil, notes: notes) == 0)
    }
    #endif

    @Test func everySectionTogetherIsTheSidebarsNumber() {
        let counts = SectionBadgeCounts([.storePage: 4, .appInformation: 2, .subscriptionPricing: 1])
        #expect(counts.total == 7)
        #expect(SectionBadgeCounts().total == 0)
    }

    #if DEBUG
    @Test func captionsAndPricesCountTowardTheirSections() {
        let center = ScreenshotsDocumentCenter(diskStore: nil)
        center.didSave(ScreenshotsDebugDocuments.standard, appID: "1")
        let counts = SectionBadgeCounts(appID: "1", suggestions: FieldSuggestionStore(), screenshots: center, pricing: 2)
        #expect(counts.count(for: .screenshots) == 3)
        #expect(counts.count(for: .subscriptionPricing) == 2)
        #expect(counts.total == 5)
        #expect(SectionBadgeCounts(appID: "2", suggestions: FieldSuggestionStore(), screenshots: center).total == 0)
    }

    @Test func pricingHasNoneWhenTheAppKeepsItsPrices() {
        let summaries = AppSummaryStore(services: .debug)
        summaries.setPricingSuggestionCount(3, for: "1")
        let modes = PricingModeStore(defaults: nil, modes: ["1": .keepPrices])
        #expect(SectionBadgeCounts.pricingCount(appID: "1", summaries: summaries, modes: modes, changes: ChangeQueue()) == 0)
    }

    @Test func pricingUsesItsExactCountOnceItReadEveryProduct() {
        let summaries = AppSummaryStore(services: .debug)
        let modes = PricingModeStore(defaults: nil)
        // Nothing read yet: no summary, no estimate.
        #expect(SectionBadgeCounts.pricingCount(appID: "1", summaries: summaries, modes: modes, changes: ChangeQueue()) == 0)
        summaries.setPricingSuggestionCount(3, for: "1")
        #expect(SectionBadgeCounts.pricingCount(appID: "1", summaries: summaries, modes: modes, changes: ChangeQueue()) == 3)
        summaries.invalidate("1")
        #expect(summaries.pricingSuggestionCounts["1"] == nil)
    }
    #endif

    @Test func repliesAndEventLanguagesCountTowardTheirSections() {
        let extras = SectionBadgeCounts.Extras(newFindings: 2, reviewReplies: 6, eventLanguages: 9)
        let counts = SectionBadgeCounts(appID: "1", suggestions: FieldSuggestionStore(), extras: extras)
        #expect(counts.count(for: .reviews) == 6)
        #expect(counts.count(for: .inAppEvents) == 9)
        #expect(counts.count(for: .analytics) == 2)
        // The app menu's purple total is suggestions only: not the gray findings.
        #expect(counts.total == 15)
    }

    @Test func eachSectionSaysItsOwnCount() {
        let counts = SectionBadgeCounts([.inAppEvents: 9, .reviews: 1], newFindings: 2)
        #expect(counts.accessibilityText(for: .inAppEvents) == "In-App Events, 9 suggestions to review")
        #expect(counts.accessibilityText(for: .reviews) == "Reviews, 1 suggestion to review")
        #expect(counts.accessibilityText(for: .analytics) == "Analytics, 2 new findings")
        #expect(counts.accessibilityText(for: .overview) == "Overview")
    }
}
