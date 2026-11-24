//
//  WorkspaceToolbarLayout.swift
//  Atlas
//

import CoreGraphics

/// What the workspace toolbar shows at the detail column's width. It always
/// leads with the section's title and status; while the sidebar is hidden
/// the section menu comes first. The Autopilot and Review & Push labels
/// fold to their icons, their counts staying, only when the toolbar has no
/// room for them: the room is the fixed part plus what the items reported
/// (`ToolbarRoomItem`: the labels, the language picker, Pro). Under 620
/// points the title goes too.
struct WorkspaceToolbarLayout: Equatable {
    var detailWidth: CGFloat = 0
    var isSidebarShown = true
    /// Each item's reported width; 0 or missing takes no room.
    var room: [ToolbarRoomItem: CGFloat] = [:]

    /// The toolbar with both labels folded: the title's least width (it
    /// truncates), Autopilot's icon and arrow, Refresh and Activity, Review
    /// & Push's icon and count, the gaps between them and the edges.
    static let fixedRoom: CGFloat = 440
    /// The window's buttons, the sidebar button and the section menu, which
    /// share the toolbar while the sidebar is hidden.
    static let hiddenSidebarRoom: CGFloat = 190
    /// Between an item of its own and the next.
    static let itemGap: CGFloat = 8
    /// Narrower than this, the title goes.
    static let titleWidth: CGFloat = 620
    static let maxTitleWidth: CGFloat = 320

    /// How wide the column must be for both labels.
    var widthForLabels: CGFloat {
        let reported = room.reduce(CGFloat(0)) { total, entry in
            entry.value > 0 ? total + entry.value + (entry.key.isItem ? Self.itemGap : 0) : total
        }
        return Self.fixedRoom + (isSidebarShown ? 0 : Self.hiddenSidebarRoom) + reported
    }

    /// The labels don't fit; not before the column is measured.
    var isCompact: Bool {
        detailWidth > 0 && detailWidth < widthForLabels
    }

    /// The section's title and status, while there's room for them.
    var showsTitle: Bool {
        detailWidth == 0 || detailWidth >= Self.titleWidth
    }

    /// Review & Push without its label.
    var isReviewCompact: Bool { isCompact }

    /// The Autopilot button without its label.
    var isAutopilotCompact: Bool { isCompact }

    /// Keeps an item's reported width; false when it didn't change, so a
    /// report that changes nothing redraws nothing.
    mutating func report(_ item: ToolbarRoomItem, width: CGFloat) -> Bool {
        guard abs((room[item] ?? 0) - width) > 0.5 else { return false }
        room[item] = width
        return true
    }
}
