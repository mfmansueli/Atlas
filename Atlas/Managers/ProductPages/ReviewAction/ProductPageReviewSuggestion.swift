//
//  ProductPageReviewSuggestion.swift
//  Atlas
//

import Foundation

/// An assistant's suggestion to submit a page, cancel its submission or
/// start a new version (`propose_page_review_action`). It shows on the
/// page's editor; the person does it with the page's own button.
struct ProductPageReviewSuggestion: Identifiable, Hashable, Sendable {
    var id = UUID()
    var appID: StoreApp.ID
    var pageID: ProductPage.ID
    var action: ProductPageReviewAction
    /// Why, at most 110 characters.
    var why: String
    /// e.g. "Claude Code".
    var client: String
    /// How sure the assistant is, and details on demand.
    var layers: SuggestionLayers?
    var receivedAt = Date.now
}
