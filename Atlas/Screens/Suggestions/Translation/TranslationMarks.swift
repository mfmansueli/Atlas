//
//  TranslationMarks.swift
//  Atlas
//

import SwiftUI

/// Board 77's marks in a text: the phrases a note says read like a
/// translation (in Suggested) and the words that moved away from the
/// original (in MEANS) get an amber dotted underline; what they say goes
/// in the text's tooltip.
enum TranslationMarks {
    /// `text` with each of `phrases` underlined where it first appears.
    static func marked(_ text: String, phrases: [String]) -> AttributedString {
        var attributed = AttributedString(text)
        for phrase in phrases where !phrase.isEmpty {
            guard let range = attributed.range(of: phrase) ?? attributed.range(of: phrase, options: .caseInsensitive) else { continue }
            attributed[range].underlineStyle = Text.LineStyle(pattern: .dot, color: Palette.warn)
        }
        return attributed
    }

    /// The phrases of `phrases` that `text` has, for tests and tooltips.
    static func found(in text: String, phrases: [String]) -> [String] {
        phrases.filter { !$0.isEmpty && text.range(of: $0, options: .caseInsensitive) != nil }
    }
}
