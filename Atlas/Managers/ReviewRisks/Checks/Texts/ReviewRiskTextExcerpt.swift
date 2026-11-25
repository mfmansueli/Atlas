//
//  ReviewRiskTextExcerpt.swift
//  Atlas
//

import Foundation

/// The words around a phrase found in a store text, for a risk's evidence:
/// "…Try everything free for 7 days and…".
enum ReviewRiskTextExcerpt {
    /// About `radius` characters each side of the first `phrase` (case and
    /// accents ignored), cut at words; the start of the text when it isn't
    /// there.
    static func around(_ phrase: String, in text: String, radius: Int = 60) -> String {
        let flat = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard let range = flat.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return ReviewRiskEvidence.cut(flat)
        }
        let start = flat.index(range.lowerBound, offsetBy: -radius, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(range.upperBound, offsetBy: radius, limitedBy: flat.endIndex) ?? flat.endIndex
        var excerpt = String(flat[start..<end])
        // Whole words only: a cut start or end loses its partial word.
        if start > flat.startIndex, let space = excerpt.firstIndex(of: " "), space < excerpt.endIndex {
            excerpt = "…" + String(excerpt[excerpt.index(after: space)...])
        }
        if end < flat.endIndex, let space = excerpt.lastIndex(of: " ") {
            excerpt = String(excerpt[..<space]) + "…"
        }
        return excerpt.trimmingCharacters(in: .whitespaces)
    }

    /// The store locale's name: "German" for "de-DE"; the code when Atlas
    /// doesn't know it.
    static func localeName(_ code: String) -> String {
        StoreLocaleCatalog.locale(code: code)?.name ?? code
    }
}
