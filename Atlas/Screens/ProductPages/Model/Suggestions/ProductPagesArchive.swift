//
//  ProductPagesArchive.swift
//  Atlas
//

import Foundation

/// One app's Product Pages on this Mac: the assistant's suggestions, the
/// pages made here and not pushed yet, and what the person decided that
/// App Store Connect doesn't keep.
struct ProductPagesArchive: Codable, Hashable, Sendable {
    var pageSuggestions: [ProductPageSuggestion] = []
    var textSuggestions: [ProductPageTextSuggestion] = []
    var dismissed: Set<String> = []
    /// Pages made in Atlas, until they're pushed.
    var drafts: [ProductPageDraft] = []
    /// Pages to make visible once Apple approves them (the Submit sheet's
    /// switch), by page ID or draft name.
    var visibleWhenApproved: Set<String> = []
    /// The API key couldn't change pages (403): the editor is read-only
    /// until a read or push works again.
    var keyCannotChange = false
    /// Accepted suggestions' briefs, by `ProductPageBrief.key` of the
    /// page's name: kept while a draft or a page has that name. Nil in
    /// archives written before briefs.
    var briefs: [String: ProductPageBrief]?
    /// Versions with App Review, by version ID, with the state seen last
    /// (`ProductPageReviewWatch`). Nil in archives written before it.
    var reviewStates: [String: ProductPageState]?

    func brief(named pageName: String) -> ProductPageBrief? {
        briefs?[ProductPageBrief.key(pageName)]
    }

    var openPageSuggestions: [ProductPageSuggestion] {
        pageSuggestions.filter { !dismissed.contains($0.id) }
    }

    var openTextSuggestions: [ProductPageTextSuggestion] {
        textSuggestions.filter { !dismissed.contains($0.id) }
    }
}
