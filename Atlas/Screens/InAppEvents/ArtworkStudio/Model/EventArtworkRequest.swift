//
//  EventArtworkRequest.swift
//  Atlas
//

import Foundation

/// A button on the event's Artwork panel, for the section to handle: it
/// owns the Pro gate, the open panel and Claude Code.
struct EventArtworkRequest: Hashable, Sendable {
    enum Action: Hashable, Sendable {
        /// Make the Artwork…: the Brief.
        case make
        case chooseFiles
    }

    var id = UUID()
    var action: Action
    var eventID: InAppEvent.ID
}
