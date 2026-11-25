//
//  ReviewReplySuggestion.swift
//  Atlas
//

import Foundation

/// A reply an assistant suggested for one review, in the reviewer's
/// language, with what it means in the app's language. It waits for the
/// person: nothing is sent until Send Reply.
struct ReviewReplySuggestion: Hashable, Codable, Sendable {
    var reviewID: AppReview.ID
    var text: String
    /// "In English: …"; empty when the reply is already in that language.
    var meaning: String
    /// Who suggested it, e.g. "Claude Code".
    var source: String
    var date: Date
    /// How sure the assistant is of it; nil when it didn't say and in
    /// replies saved before. Its gloss is `meaning`.
    var layers: SuggestionLayers?
    /// The published reply it would replace (`replace: true`), as it read
    /// when suggested; nil for a review without a reply. Sending it
    /// replaces Apple's response; once that reply changes, it no longer
    /// shows.
    var replaces: ReviewReply?
    /// Why the published reply should change, for a replacement.
    var why: String?

    /// A new text for a reply already on the App Store.
    var isReplacement: Bool { replaces != nil }
}
