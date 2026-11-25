//
//  InAppEventsViewModel+SubmitSuggestion.swift
//  Atlas
//

import Foundation

/// An assistant's suggestion to submit the open event on its own: shown
/// while the event can still go to App Review by itself.
extension InAppEventsViewModel {
    var submitSuggestion: InAppEventSubmitSuggestion? {
        guard let event = selectedEvent else { return nil }
        switch status(of: event) {
        case .draft, .rejected: return InAppEventSubmitSuggestionStore.shared.suggestion(for: app.id, eventID: event.id)
        default: return nil
        }
    }

    func dismissSubmitSuggestion() {
        guard let event = selectedEvent else { return }
        InAppEventSubmitSuggestionStore.shared.remove(for: app.id, eventID: event.id)
    }
}
