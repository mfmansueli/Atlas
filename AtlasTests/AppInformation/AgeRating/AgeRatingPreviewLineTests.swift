//
//  AgeRatingPreviewLineTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The App Store preview's Age Rating beside App Information: Now |
/// Suggested.
@Suite("Age rating preview line")
struct AgeRatingPreviewLineTests {
    private let every = Set(AgeRatingQuestion.allCases)

    @Test func unansweredAndNeverRatedIsNotRatedYet() {
        let line = AgeRatingPreviewLine.text(values: AgeRatingValues(), answered: [])
        #expect(line == AppStorePreviewText(value: "Not rated yet"))
    }

    @Test func everyQuestionAnsweredShowsTheRating() {
        let values = AgeRatingValues()
        let line = AgeRatingPreviewLine.text(values: values, answered: every)
        #expect(line.value == values.preview.effective.title)
        #expect(!line.isSuggested)
    }

    @Test func appStoreConnectsRatingCountsAsRated() {
        var values = AgeRatingValues()
        values.currentRating = "4+"
        #expect(AgeRatingPreviewLine.text(values: values, answered: []).value == values.preview.effective.title)
    }

    @Test func suggestedAnswersFillTheRestAndAreHighlighted() {
        let values = AgeRatingValues()
        let answered = every.subtracting([.gambling])
        let line = AgeRatingPreviewLine.text(values: values, answered: answered, suggested: [.gambling: .affirmative])
        var answers = values.answers
        answers[.gambling] = .affirmative
        #expect(line.value == AgeRatingCalculator.preview(for: answers, override: nil).effective.title)
        #expect(line.isSuggested)
    }

    @Test func aSuggestionThatChangesNothingIsntHighlighted() {
        let values = AgeRatingValues()
        let line = AgeRatingPreviewLine.text(values: values, answered: every, suggested: [.gambling: .negative])
        #expect(line.value == values.preview.effective.title)
        #expect(!line.isSuggested)
    }
}
