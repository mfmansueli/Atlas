//
//  GracePeriodSuggestionStore.swift
//  Atlas
//

import Foundation
import Observation

/// The assistants' Billing Grace Period suggestions per app, while Atlas
/// runs. Turning it on, or Dismiss, removes the app's.
@MainActor
@Observable
final class GracePeriodSuggestionStore {
    static let shared = GracePeriodSuggestionStore()

    private(set) var suggestions: [StoreApp.ID: GracePeriodSuggestion] = [:]

    func suggestion(for appID: StoreApp.ID) -> GracePeriodSuggestion? {
        suggestions[appID]
    }

    func suggest(_ suggestion: GracePeriodSuggestion) {
        suggestions[suggestion.appID] = suggestion
    }

    func remove(for appID: StoreApp.ID) {
        suggestions[appID] = nil
    }
}
