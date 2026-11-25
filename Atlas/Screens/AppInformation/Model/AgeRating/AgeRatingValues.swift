//
//  AgeRatingValues.swift
//  Atlas
//

import Foundation

/// The Age Rating page's values: the questionnaire and the override.
struct AgeRatingValues: Hashable, Sendable {
    var answers = AgeRatingAnswers()
    /// "Rate higher than calculated"; nil when off.
    var override: AgeRating?
    /// The rating App Store Connect shows now (`appStoreAgeRating`), e.g.
    /// "4+"; nil before the questionnaire was ever answered.
    var currentRating: String?
    /// The declaration's attributes as App Store Connect sent them, for
    /// conflict checks: an unanswered boolean is `null`, not false.
    var apiValues: [String: AppInformationAPIValue] = [:]

    /// Whether App Store Connect has an answer for it (an unanswered
    /// question reads as None or No).
    func isAnswered(_ question: AgeRatingQuestion) -> Bool {
        if case .null = apiValues[question.apiKey] ?? .null { return false }
        return true
    }

    /// `kidsAgeBand`: `FIVE_AND_UNDER`, `SIX_TO_EIGHT` or `NINE_TO_ELEVEN`
    /// when the app is in the Kids Category; nil otherwise.
    var kidsAgeBand: String? { apiValues[Self.kidsAgeBandKey]?.stringValue }

    /// The app is in the Kids Category: "For Kids" is its to use (2.3.8).
    var isKidsCategory: Bool { !(kidsAgeBand ?? "").isEmpty }

    /// The declaration's attribute name.
    static let kidsAgeBandKey = "kidsAgeBand"

    var preview: AgeRatingPreview {
        AgeRatingCalculator.preview(for: answers, override: override)
    }
}
