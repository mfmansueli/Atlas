//
//  WorkspaceToolbarLayout.swift
//  Atlas
//

import CoreGraphics

/// What the workspace toolbar shows at the detail column's width. It always
/// leads with the section's title and status; while the sidebar is hidden
/// the section menu comes first. At 860 points (the minimum window with the
/// sidebar hidden) the Autopilot and Review & Push labels fold to their
/// icons, their counts staying; under 620 points the title goes too.
struct WorkspaceToolbarLayout: Equatable {
    var detailWidth: CGFloat = 0

    /// This wide or narrower, the labels fold.
    static let compactWidth: CGFloat = 860
    /// Narrower than this, the title goes.
    static let titleWidth: CGFloat = 620
    static let maxTitleWidth: CGFloat = 320

    /// Not before the column is measured.
    var isCompact: Bool {
        detailWidth > 0 && detailWidth <= Self.compactWidth
    }

    /// The section's title and status, while there's room for them.
    var showsTitle: Bool {
        detailWidth == 0 || detailWidth >= Self.titleWidth
    }

    /// Review & Push without its label.
    var isReviewCompact: Bool { isCompact }

    /// The Autopilot button without its label.
    var isAutopilotCompact: Bool { isCompact }
}
