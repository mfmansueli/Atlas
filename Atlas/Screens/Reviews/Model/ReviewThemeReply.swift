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
}
