//
//  TranslationNote.swift
//  Atlas
//

import Foundation

/// A phrase of a suggestion that reads like a translation, with what a
/// native speaker would write and why: "über Jahre an Einträgen → in
/// Einträgen aus vielen Jahren · English word order." The card underlines
/// the phrase in Suggested and lists up to two notes under the Sounds line.
struct TranslationNote: Hashable, Codable, Sendable {
    /// The phrase exactly as the suggestion has it.
    var phrase: String
    /// What a native speaker would write instead.
    var natural: String
    /// Why, at most 110 characters.
    var why: String
}
