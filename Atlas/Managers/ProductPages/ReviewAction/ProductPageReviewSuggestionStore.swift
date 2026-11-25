//
//  ProductPageReviewSuggestionStore.swift
//  Atlas
//

import Foundation
import Observation

/// The assistants' page review suggestions, one per page, while Atlas
/// runs. Doing it, or Dismiss, removes the page's.
@MainActor
@Observable
final class ProductPageReviewSuggestionStore {
    static let shared = ProductPageReviewSuggestionStore()

    private struct Key: Hashable {
        var appID: StoreApp.ID
        var pageID: ProductPage.ID
    }

    private var suggestions: [Key: ProductPageReviewSuggestion] = [:]

    func suggestion(for appID: StoreApp.ID, pageID: ProductPage.ID) -> ProductPageReviewSuggestion? {
        suggestions[Key(appID: appID, pageID: pageID)]
    }

    func suggest(_ suggestion: ProductPageReviewSuggestion) {
        suggestions[Key(appID: suggestion.appID, pageID: suggestion.pageID)] = suggestion
    }

    func remove(for appID: StoreApp.ID, pageID: ProductPage.ID) {
        suggestions[Key(appID: appID, pageID: pageID)] = nil
    }

    /// Removes the page's suggestion when it was for `action`.
    func done(_ action: ProductPageReviewAction, appID: StoreApp.ID, pageID: ProductPage.ID) {
        guard suggestion(for: appID, pageID: pageID)?.action == action else { return }
        remove(for: appID, pageID: pageID)
    }
}
