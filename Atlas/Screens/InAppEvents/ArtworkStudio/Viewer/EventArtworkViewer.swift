//
//  EventArtworkViewer.swift
//  Atlas
//

import Foundation

/// The full-size viewer over the window (board 47): the concept shown (nil
/// for the event's own images), its card or details image, the App
/// Store's text over it and where that text goes, the viewer's own
/// language, full screen, and the Ask for Changes panel.
struct EventArtworkViewer: Hashable, Sendable {
    var conceptID: EventArtworkConcept.ID?
    var kind: InAppEventMedia.Kind
    /// The viewer's language for the App Store's text; the page keeps its own.
    var locale: String
    var showsText = true
    var showsTextArea = false
    var isFull = false
    /// Full screen was turned on by the viewer, so leaving it turns it off.
    var enteredFullScreen = false
    var isAsking = false
    var request = ""

    static let defaultRequest = String(localized: "Make the moon larger and move the lights a little to the right.")
}
