//
//  InAppEventsDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The state an In-App Events DEBUG scene opens in: the event, the
/// language, and whether every suggested language was accepted.
struct InAppEventsDebugLaunch {
    /// Taken by the section when it builds its view model.
    @MainActor static var pending: InAppEventsDebugLaunch?

    var eventID = DebugInAppEventsData.winterID
    var locale = "de-DE"
    /// Accept All Languages was pressed.
    var acceptsAll = false
    var opensNewEvent = false

    @MainActor
    func apply(to model: InAppEventsViewModel) {
        model.now = { DebugReviewsData.today }
        model.select(eventID)
        if acceptsAll {
            model.acceptAllLanguages()
            model.toast = nil
        }
        if model.selectedEvent.map({ model.languages(of: $0).contains { $0.code == locale } }) == true { model.localeCode = locale }
        model.isNewEventPresented = opensNewEvent
    }
}
#endif
