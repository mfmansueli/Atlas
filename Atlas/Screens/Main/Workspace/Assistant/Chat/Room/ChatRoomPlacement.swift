//
//  ChatRoomPlacement.swift
//  Atlas
//

import CoreGraphics

/// What on a page leaves the room the chat's pill needs at the content's
/// bottom edge (board 69), so the page's last content, or its bar, ends
/// above the pill instead of under it. The prototype does it with the
/// page's bottom padding (`padding-bottom: 58px` on the product page);
/// each kind of container here takes it the way it can scroll past it.
enum ChatRoomPlacement: CaseIterable {
    /// A page's vertical `ScrollView`: its content scrolls up past the
    /// pill (a bottom content margin), and its background still runs to
    /// the edge. Horizontal scrollers and text editors inside keep theirs.
    case scrollContent
    /// A page that doesn't scroll as a whole and fills the height (boxes
    /// with their own scrollers, a bar pinned to the bottom edge, a
    /// `List` or `Table`, which content margins don't reach on macOS):
    /// padding under it, so its bottom ends above the pill.
    case bottomEdge

    /// The bottom content margin for `room` (the environment's
    /// `chatCornerRoom`): only a vertical scroll view's.
    func contentMargin(room: CGFloat) -> CGFloat {
        self == .scrollContent ? max(0, room) : 0
    }

    /// The bottom padding for `room`: only a page pinned to the edge.
    func padding(room: CGFloat) -> CGFloat {
        self == .bottomEdge ? max(0, room) : 0
    }
}
