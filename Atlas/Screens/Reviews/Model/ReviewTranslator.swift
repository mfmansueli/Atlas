//
//  ReviewTranslator.swift
//  Atlas
//

import Foundation

/// Translates review text into the app's language. Apple Translation is
/// the real one, on this Mac; tests and DEBUG scenes use canned text.
protocol ReviewTranslator: Sendable {
    /// Whether text in `source` ("de") can be translated into `target`
    /// ("en") right now, needs a download first, or not at all.
    func availability(from source: String, to target: String) async -> TranslationAvailability
    /// `texts`, translated in order. Throws when the pair isn't ready.
    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String]
}
