//
//  AssistantChatRoom.swift
//  Atlas
//

import CoreGraphics

/// Where the closed chat (board 69) sits in the content's bottom-right
/// corner, and the room a page with a bar on its bottom edge leaves under
/// it. The prototype keeps them apart the same way: the product page leaves
/// the pill's height and a gap at its bottom (`padding-bottom: 58px`), so
/// the selection bar's actions and the last rows end above the pill, and a
/// toast lifts the pill above itself (`cb-lift`).
enum AssistantChatRoom {
    /// The pill's distance from the content's trailing edge.
    static let trailingInset = Spacing.large
    /// The pill's distance from the content's bottom edge with no toast.
    static let bottomInset = Spacing.medium
    /// Between the pill and what sits above it: a page's bottom bar, or a toast.
    static let gap = Spacing.small
    /// A toast's distance from the content's bottom edge.
    static let toastInset = Spacing.large

    /// What a page with a bar on its bottom edge leaves under it for the
    /// closed pill: the pill's place, its height and the gap.
    static let pageRoom = bottomInset + Metrics.chatPillHeight + gap

    /// The pill's distance from the content's bottom edge: above the toast
    /// while one shows.
    static func bottomPadding(isToastShown: Bool) -> CGFloat {
        isToastShown ? toastInset + Metrics.chatPillHeight + gap : bottomInset
    }
}
