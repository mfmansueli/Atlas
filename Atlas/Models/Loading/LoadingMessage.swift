//
//  LoadingMessage.swift
//  Atlas
//

import Foundation

/// What a skeleton says while non-AI data loads: what VoiceOver reads
/// once for the whole skeleton ("Loading the product pages"), and the
/// line the design shows over some skeletons ("Reading Lumen's product
/// pages…"). README-DS §9: what is loading, not "Loading…", at most six
/// words.
struct LoadingMessage: Equatable, Sendable {
    /// VoiceOver's label for the whole skeleton.
    let spoken: String
    /// The grey line over the skeleton; nil where the design shows none.
    var line: String?

    /// README-DS §9's limit for a loading line.
    static let maximumLineWords = 6

    /// The line's words, as README-DS counts them.
    var lineWordCount: Int { line.map(Self.wordCount) ?? 0 }

    /// The line keeps README-DS §9's template: six words at most, says what
    /// loads (never a bare "Loading…") and ends with an ellipsis.
    var followsCopyRules: Bool {
        guard !spoken.isEmpty else { return false }
        guard let line else { return true }
        let words = Self.wordCount(line)
        return words > 1 && words <= Self.maximumLineWords && line.hasSuffix("…")
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
