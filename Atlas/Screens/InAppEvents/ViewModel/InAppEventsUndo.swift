//
//  InAppEventsUndo.swift
//  Atlas
//

import Foundation

/// What Undo puts back after accepting suggested languages, or using an
/// artwork concept: the suggestions, the queue without the changes it
/// made, and the concept the event used before.
struct InAppEventsUndo: Hashable, Sendable {
    var suggestions: [InAppEventTextSuggestion]
    /// The changes that were queued before, by id (nil for none).
    var previous: [PendingChange.ID: PendingChange?]
    /// The artwork run whose used concept goes back to `previousConceptID`.
    var artwork: EventArtworkRun.Key?
    var previousConceptID: EventArtworkConcept.ID?
    var previousChangeIDs: [PendingChange.ID] = []
}
