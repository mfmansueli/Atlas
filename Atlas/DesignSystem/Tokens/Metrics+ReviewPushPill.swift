//
//  Metrics+ReviewPushPill.swift
//  Atlas
//

import CoreGraphics

/// Review & Push at the bottom of the window (board 80) and the chip that
/// flies to it when something is accepted.
extension Metrics {
    /// As tall as the Autopilot bar beside it.
    static let reviewPushPillHeight: CGFloat = 44
    /// Its count's badge, as tall as it is wide at least.
    static let reviewPushBadgeSize: CGFloat = 24
    /// In a narrower window it shows its icon and count only.
    static let reviewPushCompactWindowWidth: CGFloat = 700
    /// The “What's New · German” chip that flies to it…
    static let pushChipHeight: CGFloat = 26
    /// …cut short past this width.
    static let pushChipMaxWidth: CGFloat = 260
}
