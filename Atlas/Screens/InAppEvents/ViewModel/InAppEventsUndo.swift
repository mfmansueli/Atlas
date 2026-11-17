//
//  InAppEventsUndo.swift
//  Atlas
//

import Foundation

/// What Undo puts back after accepting suggested languages: the
/// suggestions, and the queue without the changes accepting made.
struct InAppEventsUndo: Hashable, Sendable {
    var suggestions: [InAppEventTextSuggestion]
    /// The changes that were queued before, by id (nil for none).
    var previous: [PendingChange.ID: PendingChange?]
}
