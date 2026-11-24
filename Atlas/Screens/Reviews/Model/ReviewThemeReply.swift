//
//  ReviewThemeReply.swift
//  Atlas
//

import Foundation

/// One language's message for Reply to All: every review of the group
/// written in that language gets it.
struct ReviewThemeReply: Hashable, Codable, Sendable {
    /// "de", "ja", "pt": matched against each review's language.
    var languageCode: String
    var text: String
    /// What it says in English, shown as "Means: …" under it; nil when the
    /// assistant sent none and in messages saved before.
    var gloss: String?
}
