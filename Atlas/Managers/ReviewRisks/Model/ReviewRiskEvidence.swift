//
//  ReviewRiskEvidence.swift
//  Atlas
//

import Foundation

/// Where a risk shows, as written: "Description · English (U.S.)" and the
/// words that break the rule, so the person (and an assistant) can find it.
struct ReviewRiskEvidence: Codable, Hashable, Sendable {
    /// The place, in the person's words: "Description · German".
    var place: String
    /// The words as written, cut to about 160 characters; empty when the
    /// risk is something missing.
    var excerpt: String
    /// The store locale code it's in, e.g. "de-DE"; nil for the whole app.
    var locale: String?

    init(place: String, excerpt: String = "", locale: String? = nil) {
        self.place = place
        self.excerpt = Self.cut(excerpt)
        self.locale = locale
    }

    /// About 160 characters, cut at a word with "…".
    static func cut(_ text: String, limit: Int = 160) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let prefix = trimmed.prefix(limit)
        let end = prefix.lastIndex(where: \.isWhitespace) ?? prefix.endIndex
        return String(prefix[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
