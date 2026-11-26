//
//  WorkspaceToolbarLayout.swift
//  Atlas
//

import CoreGraphics

/// What the workspace toolbar shows at the detail column's width. It always
/// leads with the section's title and status; while the sidebar is hidden
/// the section menu and Refresh come first (README-DS §15: Refresh lives in
/// the sidebar's top row otherwise, and Activity inside Review & Push). The actions sit at the trailing edge, and
/// everything must fit beside them: an item AppKit can't fit goes into the
/// toolbar's “»” menu, and the space it leaves stays empty, so the actions
/// no longer reach the edge. So, as the column narrows, the title truncates
/// first (`titleRoom`), down to `minimumTitleWidth`; then the Review &
/// Push label folds to its icon, its count staying
/// (`isCompact`). The room is the fixed part plus what the items reported
/// (`ToolbarRoomItem`: the title, the labels, the section menu, Pro).
/// Under 620 points the title goes too.
struct WorkspaceToolbarLayout: Equatable {
    var detailWidth: CGFloat = 0
    var isSidebarShown = true
    /// Each item's reported width; 0 or missing takes no room.
    var room: [ToolbarRoomItem: CGFloat] = [:]

    /// The toolbar's actions with the label folded, measured beside the
    /// sidebar: Review & Push's icon and count (81), the gaps between them
    /// and the title (2 × 8), the edges (2 × 4), and a few points to spare
    /// for a wider count. Autopilot is the bar at the bottom of the section
    /// (board 80); Refresh and Activity left the toolbar (board 90).
    static let fixedRoom: CGFloat = 111
    /// The window's buttons, the sidebar button and Refresh (its 28 pt
    /// button in the toolbar's glass, and its gap), which share the
    /// toolbar while the sidebar is hidden (the section menu reports its
    /// own width).
    static let hiddenSidebarRoom: CGFloat = 136 + 44
    /// Beside the sidebar, the title's room from the sidebar's edge.
    static let titleInset: CGFloat = Spacing.medium
    /// Between an item of its own and the next.
    static let itemGap: CGFloat = 8
    /// Narrower than this, the title goes.
    static let titleWidth: CGFloat = 620
    static let maxTitleWidth: CGFloat = 320
    /// The title truncates down to this before the labels fold.
    static let minimumTitleWidth: CGFloat = 180
    /// The least the title is offered when even folded labels leave less
    /// (a hidden sidebar with Pro): “Overv…”.
    static let leastTitleWidth: CGFloat = 60

    /// What the items other than the title and the section menu take: the
    /// labels, or else the items of their own (Pro)
    /// with their gaps.
    private func reported(labels: Bool) -> CGFloat {
        room.reduce(CGFloat(0)) { total, entry in
            guard entry.value > 0, entry.key.isLabel == labels, !entry.key.isLead else { return total }
            return total + entry.value + (entry.key.isItem ? Self.itemGap : 0)
        }
    }

    /// The toolbar's leading part, title aside: the title's inset beside
    /// the sidebar, else the window's buttons, the sidebar button and the
    /// section menu.
    private var leadRoom: CGFloat {
        isSidebarShown ? Self.titleInset : Self.hiddenSidebarRoom + (room[.sectionMenu] ?? 0)
    }

    /// The title's width at most when it truncates: its own when narrower.
    /// Before it's measured, and while it's gone, its room stays, so the
    /// labels don't unfold when the title goes under 620 points.
    private var leastTitleRoom: CGFloat {
        guard let title = room[.title], title > 0 else { return Self.minimumTitleWidth }
        return min(title, Self.minimumTitleWidth)
    }

    /// How wide the column must be for both labels.
    var widthForLabels: CGFloat {
        Self.fixedRoom + leadRoom + leastTitleRoom + reported(labels: true) + reported(labels: false)
    }

    /// The labels don't fit; not before the column is measured.
    var isCompact: Bool {
        detailWidth > 0 && detailWidth < widthForLabels
    }

    /// The section's title and status, while there's room for them.
    var showsTitle: Bool {
        detailWidth == 0 || detailWidth >= Self.titleWidth
    }

    /// The most the title may take, so the actions keep their place at the
    /// trailing edge; nil before the column is measured.
    var titleRoom: CGFloat? {
        guard detailWidth > 0 else { return nil }
        let actions = Self.fixedRoom + leadRoom + reported(labels: false) + (isCompact ? 0 : reported(labels: true))
        return min(Self.maxTitleWidth, max(Self.leastTitleWidth, (detailWidth - actions).rounded(.down)))
    }

    /// Review & Push without its label.
    var isReviewCompact: Bool { isCompact }

    /// Keeps an item's reported width; false when it didn't change, so a
    /// report that changes nothing redraws nothing.
    mutating func report(_ item: ToolbarRoomItem, width: CGFloat) -> Bool {
        guard abs((room[item] ?? 0) - width) > 0.5 else { return false }
        room[item] = width
        return true
    }
}
