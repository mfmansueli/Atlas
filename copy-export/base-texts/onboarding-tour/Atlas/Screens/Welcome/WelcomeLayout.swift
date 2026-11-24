//
//  WelcomeLayout.swift
//  Atlas
//

import CoreGraphics

/// How big the welcome screens' parts are for a window size, from the
/// design: the large header is 52% of the window (44% from 680 points of
/// height down, never under 210) with the mark at 38% of the height up to
/// 300; Connect's compact header is at most 150 (22%) with a mark up to
/// 118 (17%). Below 680 points the three points keep only their titles.
struct WelcomeLayout: Hashable, Sendable {
    var windowSize: CGSize

    static let shortHeight: CGFloat = 680

    var isShort: Bool { windowSize.height <= Self.shortHeight }

    var largeHeaderHeight: CGFloat {
        max(210, windowSize.height * (isShort ? 0.44 : 0.52))
    }

    var largeMarkSize: CGFloat { min(300, windowSize.height * 0.38) }

    var compactHeaderHeight: CGFloat { min(150, windowSize.height * 0.22) }

    var compactMarkSize: CGFloat { min(118, windowSize.height * 0.17) }

    var showsPointDetails: Bool { !isShort }
}
