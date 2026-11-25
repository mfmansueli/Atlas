//
//  TranslationOriginal.swift
//  Atlas
//

import Foundation

/// What a suggestion's card held before Use Natural Version, so Undo puts
/// it back: the assistant's first text, what it means and how it sounded.
struct TranslationOriginal: Hashable, Codable, Sendable {
    var text: String
    var means: String?
    var sounds: SoundsNatural?
}
