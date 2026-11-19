//
//  InAppEventsDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The state an In-App Events DEBUG scene opens in: the gallery or an
/// event's page, the language, what the preview shows, and whether every
/// suggested language was accepted.
struct InAppEventsDebugLaunch {
    /// Taken by the section when it builds its view model.
    @MainActor static var pending: InAppEventsDebugLaunch?

    var eventID = DebugInAppEventsData.winterID
    var locale = "de-DE"
    /// The event's page; the gallery when false.
    var opensEvent = true
    /// The preview's Event Card | Event Details.
    var previewKind = InAppEventMedia.Kind.card
    /// The name's menu of the other events is open (`ev-menu`).
    var opensMenu = false
    /// Accept All Languages was pressed.
    var acceptsAll = false
    var opensNewEvent = false
    /// Make the Artwork… on the event, for board 47's Brief scenes.
    var opensArtwork = false

    @MainActor
    func apply(to model: InAppEventsViewModel) {
        model.now = { DebugReviewsData.today }
        if opensEvent { model.open(eventID) } else { model.select(eventID) }
        model.previewKind = previewKind
        model.isSwitchMenuShown = opensMenu
        if acceptsAll {
            model.acceptAllLanguages()
            model.toast = nil
        }
        if model.selectedEvent.map({ model.languages(of: $0).contains { $0.code == locale } }) == true { model.localeCode = locale }
        model.isNewEventPresented = opensNewEvent
        if opensArtwork, let event = model.selectedEvent { model.requestArtwork(.make, for: event) }
    }
}
#endif
