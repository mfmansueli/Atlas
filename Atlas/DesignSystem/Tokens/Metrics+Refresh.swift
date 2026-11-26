//
//  Metrics+Refresh.swift
//  Atlas
//

import CoreGraphics

/// Refresh's sizes (board 90, README-DS §15; design-tokens.json →
/// refresh). The button itself has none: it's an icon-only toolbar button,
/// the same glass circle as Hide Sidebar beside it.
extension Metrics {
    /// The amber (failed) or grey (offline) dot on its corner.
    static let refreshDotSize: CGFloat = 6
}
