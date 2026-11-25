//
//  AssetLibraryCleanupStore.swift
//  Atlas
//

import Foundation
import Observation

/// The assistants' cleanup suggestions per app, while Atlas runs: one per
/// app, the newest. Review & Push shows it above the screenshots, and the
/// Asset Library sheet opens with its files picked.
@MainActor
@Observable
final class AssetLibraryCleanupStore {
    static let shared = AssetLibraryCleanupStore()

    private(set) var suggestions: [StoreApp.ID: AssetLibraryCleanupSuggestion] = [:]

    func suggestion(for appID: StoreApp.ID) -> AssetLibraryCleanupSuggestion? {
        suggestions[appID]
    }

    func suggest(_ suggestion: AssetLibraryCleanupSuggestion) {
        suggestions[suggestion.appID] = suggestion
    }

    func remove(for appID: StoreApp.ID) {
        suggestions[appID] = nil
    }

    /// Files the person deleted leave the suggestion; it goes once none is
    /// left.
    func noteDeleted(_ fileIDs: Set<AssetLibraryFile.ID>, appID: StoreApp.ID) {
        guard var suggestion = suggestions[appID] else { return }
        suggestion.fileIDs.removeAll(where: fileIDs.contains)
        suggestions[appID] = suggestion.fileIDs.isEmpty ? nil : suggestion
    }
}
