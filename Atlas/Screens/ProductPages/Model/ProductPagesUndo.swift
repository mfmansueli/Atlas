//
//  ProductPagesUndo.swift
//  Atlas
//

import Foundation

/// What a toast's Undo puts back: the app's Product Pages changes in Review
/// & Push and its suggestions and drafts, as they were before.
struct ProductPagesUndo: Hashable, Sendable {
    var changes: [PendingChange]
    var archive: ProductPagesArchive
    /// The page the editor showed.
    var selectedPageID: ProductPage.ID?
}
