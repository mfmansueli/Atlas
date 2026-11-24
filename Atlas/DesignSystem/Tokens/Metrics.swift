//
//  Metrics.swift
//  Atlas
//

import CoreGraphics

/// Fixed sizes from the design handoff ("Metrics"). Pointer metrics, not
/// 44 pt touch targets: this is a desktop app.
enum Metrics {
    static let sidebarWidth: CGFloat = 256
    /// A section's row in the sidebar, and in a sidebar shorter than
    /// `sidebarCompactHeight` (README-DS §11, board 71).
    static let sidebarRowHeight: CGFloat = 32
    static let sidebarCompactRowHeight: CGFloat = 27
    /// Under this sidebar height the app card drops its "other apps" line
    /// and the rows tighten.
    static let sidebarCompactHeight: CGFloat = 600
    /// Settings and Help ▾ at the bottom of the sidebar.
    static let sidebarFooterButtonHeight: CGFloat = 30
    /// The fade at the bottom of the sections when they scroll under the
    /// footer.
    static let sidebarFadeHeight: CGFloat = 14
    static let inspectorWidth: CGFloat = 300
    static let tableRowHeight: CGFloat = 26
    /// A search field at the top of a menu or popover (Find a language).
    static let menuFieldHeight: CGFloat = 28
    static let tableHeaderHeight: CGFloat = 28
    /// Smallest window the layout is designed for (README — redesign, and
    /// every section's 860 × 560 boards): at this width the sidebar may be
    /// hidden, labels fold into the toolbar's overflow and pages stack.
    static let minimumWindowWidth: CGFloat = 860
    static let minimumWindowHeight: CGFloat = 560
    /// The main window's unified toolbar: its content's minimum height is
    /// `minimumWindowHeight` less this, so the whole window gets to 560.
    static let windowToolbarHeight: CGFloat = 52
    /// Overview cards wrap into as many columns as fit at this width.
    static let overviewCardMinimumWidth: CGFloat = 270
}
