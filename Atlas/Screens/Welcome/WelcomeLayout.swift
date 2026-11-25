//
//  WelcomeLayout.swift
//  Atlas
//

import CoreGraphics

/// How big the welcome screens' parts are for a window size, from the
/// design: the large header is 52% of the window (44% from 680 points of
/// height down, never under 210) with the mark at 38% of the height up to
/// 300; Connect's compact header is at most 150 (22%) with a mark up to
/// 118 (17%). Below 680 points the three points keep only their titles,
/// Welcome's quiet line hides and Connect keeps only its steps and
/// fields; below 900 points of width Connect's field hints hide. The
/// "Add Another Key…" sheet uses the same rules for its own size, and
/// stacks Connect's two cards when it's under 720 points wide.
struct WelcomeLayout: Hashable, Sendable {
    var windowSize: CGSize

    static let shortHeight: CGFloat = 680
    static let narrowWidth: CGFloat = 900
    static let sideBySideWidth: CGFloat = 720

    var isShort: Bool { windowSize.height <= Self.shortHeight }

    var largeHeaderHeight: CGFloat {
        max(210, windowSize.height * (isShort ? 0.44 : 0.52))
    }

    var largeMarkSize: CGFloat { min(300, windowSize.height * 0.38) }

    var compactHeaderHeight: CGFloat { min(150, windowSize.height * 0.22) }

    var compactMarkSize: CGFloat { min(118, windowSize.height * 0.17) }

    var showsPointDetails: Bool { !isShort }

    /// "Words, screenshots and prices…" under the tagline.
    var showsQuietLine: Bool { !isShort }

    /// Connect's line under the title and the line under each card's.
    var showsConnectExplanations: Bool { !isShort }

    /// "top of the page", "next to your key"… beside the field names.
    var showsFieldHints: Bool { windowSize.width >= Self.narrowWidth }

    /// "Before you start" beside "Then paste it here"; one over the other
    /// in a sheet too narrow for both.
    var placesCardsSideBySide: Bool { windowSize.width >= Self.sideBySideWidth }
}
