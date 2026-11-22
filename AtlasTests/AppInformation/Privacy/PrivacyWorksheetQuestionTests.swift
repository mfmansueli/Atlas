//
//  PrivacyWorksheetQuestionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Answering the assistant's open questions: the answer's effect counts at
/// once as the person's, the first question follows, a changed answer
/// starts from the baseline, and worksheets answered before this are
/// settled as they load.
@Suite("PrivacyWorksheet open questions")
struct PrivacyWorksheetQuestionTests {
    private typealias Support = PrivacyTestSupport

    /// The scan from the report: "Data Not Collected" accepted, Purchase
    /// History suggested not collected, and a question whose Yes makes it
    /// collected and linked.
    private func scannedNotCollected() -> PrivacyWorksheet {
        var worksheet = Support.proposed([(.purchases, Support.suggestion(.notCollected))])
        worksheet.proposeCollects(false, confidence: .high, by: Support.client)
        worksheet.acceptCollects()
        worksheet.ask(Support.question("q3", affects: [.purchases], ifYes: Support.collected(linked: true), ifNo: nil), at: Support.date)
        return worksheet
    }

    @Test func answeringAppliesTheEffectAsThePersonsAnswer() {
        var worksheet = Support.proposed([(.email, Support.suggestion(.notCollected, confidence: .low))])
        worksheet.edit(.support, to: .notCollected)
        worksheet.ask(Support.question(affects: [.email, .support]), at: Support.date)
        worksheet.answerQuestion("q1", with: true)
        #expect(worksheet.openQuestions.isEmpty)
        // The unreviewed suggestion it changes is edited by the person, and counts.
        #expect(worksheet[.email]?.status == .edited)
        #expect(worksheet[.email]?.answer == Support.collected(linked: true))
        #expect(worksheet[.email]?.suggestion?.answer == .notCollected)
        // A type nobody answered becomes the person's.
        #expect(worksheet[.support]?.answer == Support.collected(linked: true))
        #expect(worksheet[.support]?.status == .yours)
        // Nothing waits for review, and the first question is Yes.
        #expect(worksheet.unreviewedCount == 0)
        #expect(worksheet.collects == .yours(true))
    }

    @Test func anAnswerThatConfirmsTheSuggestionAcceptsIt() {
        var worksheet = Support.proposed([(.otherContent, Support.suggestion(.notCollected, confidence: .medium))])
        worksheet.ask(Support.question("q2", affects: [.otherContent], ifYes: .notCollected, ifNo: Support.collected()), at: Support.date)
        worksheet.answerQuestion("q2", with: true)
        #expect(worksheet[.otherContent]?.status == .accepted)
        #expect(worksheet[.otherContent]?.answer == .notCollected)
    }

    @Test func aTypeThatBecomesCollectedTurnsTheFirstQuestionYesAndShowsInTheLabel() {
        var worksheet = scannedNotCollected()
        #expect(worksheet.labelPreview.isDataNotCollected)
        worksheet.answerQuestion("q3", with: true)
        #expect(worksheet.collects?.value == true)
        #expect(worksheet.collects?.status == .edited)
        #expect(worksheet[.purchases]?.status == .edited)
        #expect(worksheet.reviewedAnswers.collected[.purchases] == Support.collected(linked: true))
        #expect(!worksheet.labelPreview.isDataNotCollected)
        #expect(worksheet.labelPreview.groups.map(\.kind) == [.linked])
        #expect(worksheet.isDone)
    }

    @Test func aTypeNobodyAnsweredBecomesThePersonsWhenCollected() {
        var worksheet = PrivacyWorksheet()
        worksheet.setCollects(false)
        worksheet.ask(Support.question(affects: [.email, .support]), at: Support.date)
        worksheet.answerQuestion("q1", with: true)
        #expect(worksheet[.email] == .yours(Support.collected(linked: true)))
        #expect(worksheet[.support] == .yours(Support.collected(linked: true)))
        #expect(worksheet.collects == .yours(true))
    }

    @Test func aNotCollectedAnswerDoesntAddRowsOrTouchTheFirstQuestion() {
        var worksheet = PrivacyWorksheet()
        worksheet.setCollects(false)
        worksheet.ask(Support.question(affects: [.email]), at: Support.date)
        worksheet.answerQuestion("q1", with: false)
        #expect(worksheet.entries.isEmpty)
        #expect(worksheet.collects == .yours(false))
        #expect(worksheet.labelPreview.isDataNotCollected)
    }

    @Test func aSummaryOnlyEffectLeavesTheTypesAsTheyWere() {
        var worksheet = scannedNotCollected()
        worksheet.answerQuestion("q3", with: false)
        #expect(worksheet[.purchases]?.status == .unreviewed)
        #expect(worksheet[.purchases]?.answer == .notCollected)
        #expect(worksheet.collects?.value == false)
        #expect(worksheet.questions.first?.effectSummary != nil)
        #expect(worksheet.typesChanged(by: worksheet.questions[0]).isEmpty)
    }

    @Test func changingTheAnswerStartsFromTheBaseline() {
        var worksheet = scannedNotCollected()
        let before = worksheet
        worksheet.answerQuestion("q3", with: true)
        #expect(worksheet.typesChanged(by: worksheet.questions[0]) == [.purchases])
        worksheet.answerQuestion("q3", with: false)
        // Purchase History is the scan's suggestion again, and the first question its No.
        #expect(worksheet[.purchases] == before[.purchases])
        #expect(worksheet.collects == before.collects)
        #expect(worksheet.labelPreview.isDataNotCollected)
        #expect(worksheet.questions.first?.answer == false)
        // And back to Yes.
        worksheet.answerQuestion("q3", with: true)
        #expect(worksheet.reviewedAnswers.collected[.purchases] == Support.collected(linked: true))
        #expect(worksheet.collects?.value == true)
    }

    @Test func theFirstQuestionStaysYesWhileSomethingElseIsCollected() {
        var worksheet = scannedNotCollected()
        worksheet.answerQuestion("q3", with: true)
        worksheet.edit(.email, to: Support.collected())
        worksheet.answerQuestion("q3", with: false)
        #expect(worksheet.collects?.value == true)
        #expect(worksheet.reviewedAnswers.collected.keys.sorted { $0.rawValue < $1.rawValue } == [.email])
    }

    @Test func aConflictTheAnswerSettlesGoesAway() {
        var worksheet = Support.answered([.email: Support.collected()])
        worksheet.propose(Support.suggestion(.notCollected), for: .email, at: Support.date)
        #expect(worksheet.conflictTypes == [.email])
        worksheet.ask(Support.question(affects: [.email]), at: Support.date)
        worksheet.answerQuestion("q1", with: false)
        #expect(worksheet[.email]?.answer == .notCollected)
        #expect(worksheet.conflictTypes.isEmpty)
    }

    @Test func answersSavedBeforeAnswersCountedAreSettledAsTheWorksheetLoads() throws {
        // What the old answering left: Purchase History rewritten in place but
        // still unreviewed, the first question still an accepted No.
        var saved = scannedNotCollected()
        saved.entries[.purchases]?.answer = Support.collected(linked: true)
        saved.questions[0].answer = true
        #expect(saved.questions[0].baseline == nil)
        #expect(saved.labelPreview.isDataNotCollected)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(PrivacyWorksheet.self, from: encoder.encode(saved))

        #expect(loaded[.purchases]?.status == .edited)
        #expect(loaded.collects?.value == true)
        #expect(loaded.reviewedAnswers.collected[.purchases] == Support.collected(linked: true))
        // The baseline is the scan's suggestion, so No still goes back to it.
        let baseline = try #require(loaded.questions.first?.baseline)
        #expect(baseline.entries[.purchases] == .suggested(Support.suggestion(.notCollected)))
        #expect(baseline.collects?.value == false)
        var changed = loaded
        changed.answerQuestion("q3", with: false)
        #expect(changed.labelPreview.isDataNotCollected)

        // Loading again changes nothing more.
        let reloaded = try decoder.decode(PrivacyWorksheet.self, from: encoder.encode(loaded))
        #expect(reloaded == loaded)
    }

    @Test func anOpenQuestionLoadsUntouched() throws {
        let worksheet = scannedNotCollected()
        let loaded = try JSONDecoder().decode(PrivacyWorksheet.self, from: JSONEncoder().encode(worksheet))
        #expect(loaded == worksheet)
    }

    @Test func getPrivacyQuestionnaireReturnsTheAnswersAndWhatTheyChanged() {
        var worksheet = scannedNotCollected()
        worksheet.ask(Support.question("q4", affects: [.email]), at: Support.date)
        worksheet.answerQuestion("q3", with: true)
        let json = worksheet.questionnaireJSON
        #expect(json["openQuestions"]?.arrayValue?.compactMap { $0["id"]?.stringValue } == ["q4"])
        let answered = json["answeredQuestions"]?.arrayValue
        #expect(answered?.count == 1)
        #expect(answered?.first?["id"] == "q3")
        #expect(answered?.first?["answer"] == true)
        #expect(answered?.first?["changed"] == ["purchases"])
        #expect(answered?.first?["effect"] == "Collected")
        #expect(json["collects"] == true)
    }
}
