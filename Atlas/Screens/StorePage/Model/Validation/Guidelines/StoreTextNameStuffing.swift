//
//  StoreTextNameStuffing.swift
//  Atlas
//

import Foundation

/// Names and subtitles packed with search terms (Guideline 2.3.7: "don't
/// stuff your name with keywords"), and keywords that repeat what App
/// Store search already reads in the name and subtitle.
nonisolated enum StoreTextNameStuffing {
    /// At this many separators a name reads as a list of search terms:
    /// "Notes | Todo | Planner | Journal".
    static let separatorLimit = 3

    /// The separators in `text`, in order: "|", "·", "•", "–", "—", ",",
    /// "/" (not "24/7") and a spaced hyphen (" - "; "To-Do" and "Wi-Fi"
    /// aren't).
    static func separators(in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return (separator?.matches(in: text, range: range) ?? []).compactMap { match in
            Range(match.range, in: text).map { text[$0].trimmingCharacters(in: .whitespaces) }
        }
    }

    /// Reads as a list of search terms.
    static func isStuffed(_ text: String) -> Bool {
        separators(in: text).count >= separatorLimit
    }

    /// The name and subtitle say the same, whatever the case and spacing.
    static func isSame(_ name: String, _ subtitle: String) -> Bool {
        let left = words(in: name)
        return !left.isEmpty && left == words(in: subtitle)
    }

    /// The keywords (as written) that are words of the name or subtitle,
    /// or made only of them: App Store search reads those already.
    static func repeatedKeywords(_ keywords: String, name: String, subtitle: String) -> [String] {
        let known = Set(words(in: name) + words(in: subtitle))
        guard !known.isEmpty else { return [] }
        return keywordList(keywords).filter { keyword in
            let parts = words(in: keyword)
            return !parts.isEmpty && parts.allSatisfy { known.contains($0) }
        }
    }

    /// The keywords split at commas (also "、" and "，"), trimmed.
    static func keywordList(_ keywords: String) -> [String] {
        keywords.components(separatedBy: CharacterSet(charactersIn: ",、，;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Words folded (case, accents), in order.
    static func words(in text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var words: [String] = []
        folded.enumerateSubstrings(in: folded.startIndex..., options: .byWords) { word, _, _, _ in
            if let word { words.append(word) }
        }
        return words
    }

    private static let separator = try? NSRegularExpression(pattern: "[|·•–—,]|(?<!\\d)/(?!\\d)|\\s-\\s")
}
