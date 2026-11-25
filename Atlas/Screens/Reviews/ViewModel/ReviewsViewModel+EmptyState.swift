//
//  ReviewsViewModel+EmptyState.swift
//  Atlas
//

import Foundation

/// Reviews with nothing to show (board 74 · 6 and 8).
extension ReviewsViewModel {
    /// Read, and nobody has written a review yet: the section explains
    /// what will show up here instead of the filters and the list.
    var showsEmptyState: Bool { hasLoaded && reviews.isEmpty }

    /// What the list says when what's chosen shows nothing.
    var emptyListText: ReviewsEmptyText {
        ReviewsEmptyText.make(filter: filter, hasTheme: themeFilter != nil, hasTerritory: territoryFilter != nil)
    }

    /// Show All Reviews: every review, from every country and group.
    func showAllReviews() {
        editingID = nil
        themeFilter = nil
        territoryFilter = nil
        filter = .all
    }
}
