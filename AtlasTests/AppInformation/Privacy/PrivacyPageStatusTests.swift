//
//  PrivacyPageStatusTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// App Privacy's page in the canvas's structure: the status beside the
/// tabs, the Worksheet tab's count, the label people will see, and the
/// Fill In App Store Connect steps that show before the worksheet is done.
@Suite("App Privacy page")
struct PrivacyPageStatusTests {
    private typealias Support = PrivacyTestSupport

    @Test func saysWhatWaitsFirst() {
        let status = PrivacyPageStatus(status: .inProgress, openQuestions: 1, unreviewed: 3)
        #expect(status.text == "1 question · 3 to review")
        #expect(status.tone == .waiting)
        #expect(PrivacyPageStatus.waitingText(openQuestions: 2, unreviewed: 0) == "2 questions")
        #expect(PrivacyPageStatus.waitingText(openQuestions: 0, unreviewed: 4) == "4 to review")
        #expect(PrivacyPageStatus.waitingText(openQuestions: 0, unreviewed: 0) == nil)
    }

    @Test func doneIsReadyForAppStoreConnect() {
        let status = PrivacyPageStatus(status: .done, openQuestions: 0, unreviewed: 0)
        #expect(status.text == "Ready to fill in App Store Connect")
        #expect(status.tone == .ready)
    }

    @Test func publishedSaysWhen() {
        let status = PrivacyPageStatus(status: .published(Support.date), openQuestions: 0, unreviewed: 0)
        #expect(status.text.hasPrefix("Published in App Store Connect · "))
        #expect(status.tone == .published)
    }

    @Test func otherStatesKeepTheirTitles() {
        #expect(PrivacyPageStatus(status: .notStarted, openQuestions: 0, unreviewed: 0).text == PrivacyWorksheetStatus.notStarted.title)
        let outOfDate = PrivacyPageStatus(status: .outOfDate(Support.date), openQuestions: 0, unreviewed: 2)
        #expect(outOfDate.tone == .outOfDate, "Out of date wins over what waits")
        // In progress with nothing to review, e.g. a purpose missing.
        #expect(PrivacyPageStatus(status: .inProgress, openQuestions: 0, unreviewed: 0).tone == .neutral)
    }

    @Test func worksheetTabCountsSuggestionsAndOpenQuestions() {
        var worksheet = Support.proposed([
            (.userId, Support.suggestion(Support.collected(linked: true))),
            (.email, Support.suggestion(Support.collected(linked: true), confidence: .low)),
        ])
        worksheet.ask(Support.question(), at: Support.date)
        #expect(PrivacyPageStatus.worksheetCount(worksheet) == worksheet.unreviewedCount + 1)
        #expect(PrivacyPageStatus(worksheet: worksheet).tone == .waiting)
    }

    @Test func rowsMeterHowSureEachSuggestionIs() {
        #expect(PrivacyConfidence.low.howSure == .notVerySure)
        #expect(PrivacyConfidence.medium.howSure == .fairlySure)
        #expect(PrivacyConfidence.high.howSure == .sure)
    }

    @Test func labelListsCategoriesPerGroup() {
        let worksheet = Support.answered([
            .userId: Support.collected(linked: true),
            .crash: Support.collected(),
        ])
        let preview = worksheet.labelPreview
        #expect(preview.categoryNames(in: .linked) == PrivacyDataType.userId.category.name)
        #expect(preview.categoryNames(in: .notLinked) == PrivacyDataType.crash.category.name)
        #expect(preview.categoryNames(in: .tracking) == "None")
    }
}
