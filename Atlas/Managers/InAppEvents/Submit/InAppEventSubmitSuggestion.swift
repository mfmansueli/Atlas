//
//  InAppEventSubmitSuggestion.swift
//  Atlas
//

import Foundation

/// An assistant's suggestion to send a ready event to App Review on its
/// own, without a version (`propose_event_submission`). It shows on the
/// event's page over the footer; the person submits with Submit Event… and
/// its confirmation. Nothing is submitted for them.
struct InAppEventSubmitSuggestion: Identifiable, Hashable, Sendable {
    var id = UUID()
    var appID: StoreApp.ID
    var eventID: InAppEvent.ID
    /// Why now, at most 110 characters.
    var why: String
    /// e.g. "Claude Code".
    var client: String
    /// How sure the assistant is, and details on demand.
    var layers: SuggestionLayers?
    var receivedAt = Date.now
}
