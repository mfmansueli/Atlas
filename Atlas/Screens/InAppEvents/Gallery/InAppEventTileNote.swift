//
//  InAppEventTileNote.swift
//  Atlas
//

import Foundation

/// The last line of an event's tile in the gallery (board 40): what the
/// event still needs ("3 concepts to choose from · 9 languages
/// suggested"), "Ready to submit", or how it went. Amber when the only
/// thing is a missing image, purple when Claude has something waiting.
struct InAppEventTileNote: Hashable, Sendable {
    enum Tone: Hashable, Sendable {
        case secondary
        case suggestion
        case warning
    }

    var text: String
    var tone: Tone

    /// One thing the event needs; `isWarning` for a missing image.
    struct Part: Hashable, Sendable {
        var text: String
        var isWarning = false
    }

    /// The parts joined with " · ": amber when the only one is a warning,
    /// purple when there are any, `done` when there are none.
    static func make(_ parts: [Part], done: String) -> Self {
        guard !parts.isEmpty else { return InAppEventTileNote(text: done, tone: .secondary) }
        let tone: Tone = parts.count == 1 && parts[0].isWarning ? .warning : .suggestion
        return InAppEventTileNote(text: parts.map(\.text).joined(separator: " · "), tone: tone)
    }
}
