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
}
