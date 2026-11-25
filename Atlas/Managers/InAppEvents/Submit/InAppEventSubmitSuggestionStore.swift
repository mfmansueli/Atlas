//
//  InAppEventSubmitSuggestionStore.swift
//  Atlas
//

import Foundation
import Observation

/// The assistants' suggestions to submit an event on its own, while Atlas
/// runs: one per event. Submitting the event, or Dismiss, removes it.
@MainActor
@Observable
final class InAppEventSubmitSuggestionStore {
    static let shared = InAppEventSubmitSuggestionStore()

    private struct Key: Hashable {
        var appID: StoreApp.ID
        var eventID: InAppEvent.ID
    }

    private var suggestions: [Key: InAppEventSubmitSuggestion] = [:]

    func suggestion(for appID: StoreApp.ID, eventID: InAppEvent.ID) -> InAppEventSubmitSuggestion? {
        suggestions[Key(appID: appID, eventID: eventID)]
    }

    func suggest(_ suggestion: InAppEventSubmitSuggestion) {
        suggestions[Key(appID: suggestion.appID, eventID: suggestion.eventID)] = suggestion
    }

    func remove(for appID: StoreApp.ID, eventID: InAppEvent.ID) {
        suggestions[Key(appID: appID, eventID: eventID)] = nil
    }
}
