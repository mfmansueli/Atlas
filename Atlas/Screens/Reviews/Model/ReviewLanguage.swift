//
//  ReviewLanguage.swift
//  Atlas
//

import Foundation
import NaturalLanguage

/// The language a review is written in, read from its text on this Mac.
enum ReviewLanguage {
    /// "de", "ja", "pt", "zh-Hans"; "" when the text is too short or mixed
    /// to tell.
    static func code(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return "" }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return "" }
        // A few words can read as anything: keep only a confident answer.
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[language] ?? 0
        return confidence >= minimumConfidence(for: trimmed) ? language.rawValue : ""
    }

    /// Short texts need a surer answer.
    private static func minimumConfidence(for text: String) -> Double {
        text.count < 24 ? 0.6 : 0.3
    }

    /// "German", "Japanese", in the app's language; the code when it has
    /// no name.
    static func name(of code: String) -> String {
        guard !code.isEmpty else { return String(localized: "another language") }
        return appLocale.localizedString(forIdentifier: code) ?? appLocale.localizedString(forLanguageCode: code) ?? code
    }

    /// The language Atlas itself speaks, which reviews are
    /// translated into: "en".
    static var appLanguageCode: String {
        ReviewTheme.base(Bundle.main.preferredLocalizations.first ?? "en")
    }

    /// "English".
    static var appLanguageName: String {
        appLocale.localizedString(forLanguageCode: appLanguageCode) ?? "English"
    }

    /// Whether a review in `code` reads as is, without translating.
    static func isAppLanguage(_ code: String) -> Bool {
        code.isEmpty || ReviewTheme.base(code) == appLanguageCode
    }

    /// Arabic, Hebrew, Persian and Urdu run right to left.
    static func isRightToLeft(_ code: String) -> Bool {
        ["ar", "he", "fa", "ur"].contains(ReviewTheme.base(code))
    }

    private static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }
}
