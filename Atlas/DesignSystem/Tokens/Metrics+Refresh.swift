//
//  Metrics+Refresh.swift
//  Atlas
//

import CoreGraphics

/// Refresh's sizes (board 90, README-DS §15; design-tokens.json →
/// refresh): the borderless icon button in the sidebar's top row and its
/// state dot.
extension Metrics {
    /// The Refresh button, square.
    static let refreshButtonSize: CGFloat = 28
    /// The amber (failed) or grey (offline) dot on its corner.
    static let refreshDotSize: CGFloat = 6
}
