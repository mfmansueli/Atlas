//
//  EventArtworkPanelActions.swift
//  Atlas
//

import Foundation

/// What the Artwork panel's buttons and rows do, given by the event's
/// page: the section handles Make and Choose Files, the flow the rest.
struct EventArtworkPanelActions {
    var make: () -> Void = {}
    var chooseFiles: () -> Void = {}
    var stop: () -> Void = {}
    /// Opens the viewer on a concept (nil: the preview's) and an image
    /// (nil: the preview's).
    var view: (_ conceptID: EventArtworkConcept.ID?, _ kind: InAppEventMedia.Kind?) -> Void = { _, _ in }
    /// A row: the preview shows that concept.
    var preview: (EventArtworkConcept.ID) -> Void = { _ in }
    var change: () -> Void = {}
    var keepCurrent: () -> Void = {}
    var use: () -> Void = {}
    var addMotion: () -> Void = {}
}
