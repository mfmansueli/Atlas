//
//  SectionSummaryTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The summary line at the top of a section: what waits, then time.
@Suite("SectionSummary")
struct SectionSummaryTests {
    @Test func suggestionsThenTimeThenReviewAndPush() {
        let summary = SectionSummary(suggestions: 3, notPushed: 2)
        #expect(summary.text == "3 suggestions · about 2 min · 2 in Review & Push")
        #expect(summary.accessibilityText == "3 suggestions, about 2 minutes, 2 in Review & Push")
    }

    @Test func oneSuggestionTakesAboutAMinute() {
        let summary = SectionSummary(suggestions: 1, notPushed: 0)
        #expect(summary.text == "1 suggestion · about 1 min")
        #expect(summary.accessibilityText == "1 suggestion, about 1 minute")
    }

    @Test(arguments: [(1, 1), (2, 1), (3, 2), (4, 2), (5, 3), (12, 6), (31, 16)])
    func halfAMinuteASuggestionRoundedNeverUnderOne(suggestions: Int, minutes: Int) {
        #expect(SectionSummary(suggestions: suggestions, notPushed: 0).minutes == minutes)
    }

    @Test func onlyWhatIsInReviewAndPush() {
        let summary = SectionSummary(suggestions: 0, notPushed: 4)
        #expect(summary.text == "4 in Review & Push")
        #expect(summary.accessibilityText == "4 in Review & Push")
    }

    @Test func nothingWaitingHidesTheLine() {
        #expect(SectionSummary.make(section: .storePage, suggestions: 0, notPushed: 0) == nil)
        #expect(SectionSummary(suggestions: 0, notPushed: 0).text.isEmpty)
    }

    @Test func overviewAndAnalyticsShowNone() {
        #expect(SectionSummary.make(section: .overview, suggestions: 5, notPushed: 3) == nil)
        #expect(SectionSummary.make(section: .analytics, suggestions: 2, notPushed: 0) == nil)
    }

    @Test func reviewAndPushCountsOnlyWhereThePageAcceptsChanges() {
        #expect(SectionSummary.make(section: .reviews, suggestions: 0, notPushed: 3) == nil)
        #expect(SectionSummary.make(section: .inAppEvents, suggestions: 2, notPushed: 3) == SectionSummary(suggestions: 2, notPushed: 0))
        #expect(SectionSummary.make(section: .productPages, suggestions: 1, notPushed: 1)?.text == "1 suggestion · about 1 min")
        #expect(SectionSummary.make(section: .subscriptionPricing, suggestions: 2, notPushed: 1)?.text
            == "2 suggestions · about 1 min · 1 in Review & Push")
        #expect(SectionSummary.make(section: .appInformation, suggestions: 0, notPushed: 2)?.text == "2 in Review & Push")
        #expect(SectionSummary.make(section: .screenshots, suggestions: 12, notPushed: 0)?.text == "12 suggestions · about 6 min")
    }

    @Test func negativeCountsReadAsNone() {
        #expect(SectionSummary(suggestions: -2, notPushed: -1).isEmpty)
    }
}
