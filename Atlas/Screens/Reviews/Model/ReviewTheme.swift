//
//  ReviewTheme.swift
//  Atlas
//

import Foundation

/// Reviews about one subject, grouped by an assistant: what's broken, what
/// people ask for, what they love. Each group ends in one action.
struct ReviewTheme: Identifiable, Hashable, Codable, Sendable {
    /// The assistant's own id, e.g. "sync"; a later group with the same id
    /// replaces it.
    var id: String
    /// "iCloud sync since 1.3".
    var title: String
    /// "Fixed in 1.4. Replies can say so, in each reviewer’s language."
    var note: String
    var reviewIDs: [AppReview.ID]
    var action: ReviewThemeAction
    /// Reply to All's messages, one per language.
    var replies: [ReviewThemeReply] = []
    /// Who grouped them, e.g. "Claude Code".
    var source: String
    /// The rest of the note behind Details, and how sure the assistant is
    /// of the group; nil when it sent neither and in groups saved before.
    var layers: SuggestionLayers?

    /// The message for a review's language: "de" finds "de" or "de-DE".
    func reply(forLanguage code: String) -> ReviewThemeReply? {
        guard !code.isEmpty else { return nil }
        let wanted = Self.base(code)
        return replies.first { Self.base($0.languageCode) == wanted }
    }

    /// "pt-BR" → "pt".
    static func base(_ code: String) -> String {
        String(code.lowercased().prefix { $0 != "-" && $0 != "_" })
    }
}
