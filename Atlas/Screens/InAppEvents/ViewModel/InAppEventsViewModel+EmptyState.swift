//
//  InAppEventsViewModel+EmptyState.swift
//  Atlas
//

import Foundation

/// The gallery with nothing in it (board 74 · 3), and what the toolbar's
/// Autopilot button leads with.
extension InAppEventsViewModel {
    /// Read, with no event and none waiting in Review & Push to be made.
    var showsEmptyState: Bool {
        guard case .loaded = state else { return false }
        return events.isEmpty && queuedNewEvents.isEmpty
    }

    /// The open event's Make the Artwork…; Suggest an Event… while there's
    /// no event to make artwork for; otherwise the section's own order.
    var autopilotDetail: WorkspaceAutopilotDetail? {
        if showsEvent { return .event }
        return showsEmptyState ? .noEvents : nil
    }
}
