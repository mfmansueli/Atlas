//
//  ReviewRiskTermMatcher.swift
//  Atlas
//

import Foundation

/// Finds a word or phrase in a text the way the content checks need:
/// case and accents ignored, except for short capitals ("AI", "GPT",
/// "LLM") that match capitals only; whole words, except in scripts with
/// no spaces (Chinese, Japanese); any run of spaces between words; and no
/// match inside one of the topic's exclusions ("planning poker").
enum ReviewRiskTermMatcher {
    /// The first match of `term` in `text` outside `exclusions`.
    static func range(of term: String, in text: String, excluding exclusions: [String] = []) -> Range<String.Index>? {
        let excluded = exclusions.flatMap { ranges(of: $0, in: text) }
        return ranges(of: term, in: text).first { found in !excluded.contains { $0.overlaps(found) } }
    }

    /// Every match of `term` in `text`.
    static func ranges(of term: String, in text: String) -> [Range<String.Index>] {
        let term = term.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, !text.isEmpty else { return [] }
        let options: String.CompareOptions = isCapitalsOnly(term) ? [] : [.caseInsensitive, .diacriticInsensitive]
        let wholeWords = !hasCJK(term)
        let parts = term.split(whereSeparator: \.isWhitespace).map(String.init)
        var found: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex, let first = text.range(of: parts[0], options: options, range: start..<text.endIndex) {
            start = text.index(after: first.lowerBound)
            guard let match = rest(of: parts.dropFirst(), after: first, in: text, options: options) else { continue }
            if !wholeWords || isWholeWord(match, in: text) { found.append(match) }
        }
        return found
    }

    /// The phrase's next words after `first`, each after one or more
    /// spaces.
    private static func rest(
        of parts: ArraySlice<String>,
        after first: Range<String.Index>,
        in text: String,
        options: String.CompareOptions
    ) -> Range<String.Index>? {
        var end = first.upperBound
        for part in parts {
            var cursor = end
            while cursor < text.endIndex, text[cursor].isWhitespace { cursor = text.index(after: cursor) }
            guard cursor > end, let next = text.range(of: part, options: options.union(.anchored), range: cursor..<text.endIndex) else {
                return nil
            }
            end = next.upperBound
        }
        return first.lowerBound..<end
    }

    private static func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = range.lowerBound > text.startIndex ? text[text.index(before: range.lowerBound)] : nil
        let after = range.upperBound < text.endIndex ? text[range.upperBound] : nil
        return !isWordCharacter(before) && !isWordCharacter(after)
    }

    private static func isWordCharacter(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isLetter || character.isNumber
    }

    /// Two to four capitals, maybe with dots: "AI", "A.I.", "GPT", "E2EE".
    static func isCapitalsOnly(_ term: String) -> Bool {
        let letters = term.filter(\.isLetter)
        return !letters.isEmpty && letters.count <= 4 && term.count <= 5 && letters.allSatisfy(\.isUppercase)
    }

    /// Han, kana or Hangul: words aren't separated by spaces.
    static func hasCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF: true
            default: false
            }
        }
    }

    /// The words around `range`, about 120 characters, with "…" where it
    /// was cut.
    static func excerpt(around range: Range<String.Index>, in text: String, before: Int = 50, after: Int = 70) -> String {
        let start = text.index(range.lowerBound, offsetBy: -before, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: after, limitedBy: text.endIndex) ?? text.endIndex
        let words = text[start..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return (start > text.startIndex ? "…" : "") + words + (end < text.endIndex ? "…" : "")
    }
}
