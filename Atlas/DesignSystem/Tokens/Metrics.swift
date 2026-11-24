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
    /// The column a row's SF Symbol sits in (README-DS §13): the sidebar,
    /// the section menu, Settings' sidebar and the menu bar's menu, so the
    /// names line up whatever the symbol's width.
    static let symbolColumn: CGFloat = 20
    /// The same in Overview's rows, where the symbol is Title 3.
    static let largeSymbolColumn: CGFloat = 28
    static let inspectorWidth: CGFloat = 300
    static let tableRowHeight: CGFloat = 26
    /// A search field at the top of a menu or popover (Find a language).
    static let menuFieldHeight: CGFloat = 28
    static let tableHeaderHeight: CGFloat = 28
    /// A price table's checkbox, price and change columns (the recommended
    /// prices of a new subscription).
    static let tableCheckboxWidth: CGFloat = 20
    static let tablePriceColumnWidth: CGFloat = 96
    static let tableChangeColumnWidth: CGFloat = 56
    /// Smallest window the layout is designed for (README — redesign, and
    /// every section's 860 × 560 boards): at this width the sidebar may be
    /// hidden, labels fold into the toolbar's overflow and pages stack.
    static let minimumWindowWidth: CGFloat = 860
    static let minimumWindowHeight: CGFloat = 560
    /// The main window's unified toolbar: its content's minimum height is
    /// `minimumWindowHeight` less this, so the whole window gets to 560.
    static let windowToolbarHeight: CGFloat = 52
    /// The assistant chat in the window's corner (board 69): closed, a
    /// pill; open, a panel over the content that never reaches the
    /// toolbar (at most the window's height less `chatPanelClearance`).
    static let chatPillWidth: CGFloat = 340
    static let chatPillHeight: CGFloat = 36
    static let chatPanelWidth: CGFloat = 420
    static let chatPanelHeight: CGFloat = 500
    static let chatPanelClearance: CGFloat = 72
    /// The send and stop buttons, and the chat's lead mark.
    static let chatButtonSize: CGFloat = 28
    static let chatLeadSize: CGFloat = 18
    /// A push's meter in the closed chat.
    static let chatMeterWidth: CGFloat = 44
    /// Overview cards wrap into as many columns as fit at this width.
    static let overviewCardMinimumWidth: CGFloat = 270
}
