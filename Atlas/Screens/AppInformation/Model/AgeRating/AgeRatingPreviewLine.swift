//
//  AgeRatingPreviewLine.swift
//  Atlas
//

import Foundation

/// The Age Rating row of the App Store preview beside App Information
/// (Now | Suggested): the rating the answers give, “Not rated yet” while
/// App Store Connect has no rating and a question is unanswered, and with
/// Suggested the open answer suggestions on top, highlighted when they
/// change what the page shows.
enum AgeRatingPreviewLine {
    /// `answered`: the questions with an answer, from App Store Connect or
    /// waiting in Review & Push. `suggested`: the open suggestions shown
    /// (none for Now).
    static func text(
        values: AgeRatingValues, answered: Set<AgeRatingQuestion>, suggested: [AgeRatingQuestion: AgeRatingAnswer] = [:]
    ) -> AppStorePreviewText {
        let now = title(values.answers, values: values, answered: answered)
        guard !suggested.isEmpty else { return AppStorePreviewText(value: now) }
        var answers = values.answers
        for (question, answer) in suggested {
            answers[question] = answer
        }
        let withSuggestions = title(answers, values: values, answered: answered.union(suggested.keys))
        return AppStorePreviewText(value: withSuggestions, isSuggested: withSuggestions != now)
    }

    private static func title(_ answers: AgeRatingAnswers, values: AgeRatingValues, answered: Set<AgeRatingQuestion>) -> String {
        let isRated = values.currentRating != nil || AgeRatingQuestion.allCases.allSatisfy(answered.contains)
        guard isRated else { return String(localized: "Not rated yet") }
        return AgeRatingCalculator.preview(for: answers, override: values.override).effective.title
    }
}
