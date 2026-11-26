//
//  AutopilotBarRoom.swift
//  Atlas
//

import CoreGraphics

/// Where the Autopilot bar sits at the bottom of every section (board 80),
/// and the room a page leaves under its content for the bar while it's
/// closed: the bar's distance from the bottom edge, its closed height (its
/// field, and the strip above it while something happens) and a gap. A
/// toast sits in that room's top, above the bar. Open, the bar grows over
/// the page, which doesn't move.
enum AutopilotBarRoom {
    /// The bar's distance from the content's bottom edge.
    static let bottomInset = Spacing.medium
    /// The dock's distance from the content's sides.
    static let sideInset = Spacing.xLarge
    /// Between the bar and what ends above it: a page's last content, its
    /// bottom bar, or a toast.
    static let gap = Spacing.small
    /// Between the open bar's top and the top of the content.
    static let topClearance = Spacing.small

    /// The room for the closed bar with only its field.
    static let pageRoom = room(closedHeight: Metrics.autopilotBarFieldHeight)

    /// What a page leaves under its content for a closed bar of
    /// `closedHeight`: its place, its height and the gap.
    static func room(closedHeight: CGFloat) -> CGFloat {
        bottomInset + max(closedHeight, Metrics.autopilotBarFieldHeight) + gap
    }

    /// How tall the open bar is in content `height` tall: its own height,
    /// or what's left under the toolbar.
    static func openHeight(in height: CGFloat) -> CGFloat {
        max(Metrics.autopilotBarFieldHeight, min(Metrics.autopilotBarOpenHeight, height - bottomInset - topClearance))
    }
}
