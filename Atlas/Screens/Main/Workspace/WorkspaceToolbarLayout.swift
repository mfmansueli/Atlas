//
//  WorkspaceToolbarLayout.swift
//  Atlas
//

import CoreGraphics

/// What the workspace toolbar shows at the detail column's width. With the
/// sections in the sidebar it only holds actions; while the sidebar is
/// hidden it also has the section menu and the app's title. Under 720
/// points the title goes and Review & Push keeps its icon and count.
struct WorkspaceToolbarLayout: Equatable {
    var detailWidth: CGFloat = 0

    /// Narrower than this, the toolbar folds.
    static let compactWidth: CGFloat = 720
    static let maxTitleWidth: CGFloat = 240

    /// Not before the column is measured.
    var isCompact: Bool {
        detailWidth > 0 && detailWidth < Self.compactWidth
    }

    /// The app's name and version, beside the section menu: only while
    /// the sidebar, which names the app, is hidden, and there's room.
    func showsTitle(isSidebarShown: Bool) -> Bool {
        !isSidebarShown && !isCompact
    }

    /// Review & Push without its label.
    var isReviewCompact: Bool { isCompact }
}
