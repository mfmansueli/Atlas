//
//  Metrics+PricesByCountry.swift
//  Atlas
//

import CoreGraphics

/// Prices by Country's sizes (README-Redesign, board 73).
extension Metrics {
    /// Narrower than this, In US$ and How it's set fold under the country's
    /// name ("Automatic · ≈ $46").
    static let countriesNarrowWidth: CGFloat = 780
    /// Shorter than this, the price popover opens at the top of the table
    /// and its price points scroll.
    static let countriesShortHeight: CGFloat = 420
    static let countriesPopoverWidth: CGFloat = 340
    /// The popover's list of price points.
    static let countriesPointListHeight: CGFloat = 220
    static let countriesPointListMinimumHeight: CGFloat = 96
    /// What the popover's title, choices and buttons take besides the list.
    static let countriesPopoverChrome: CGFloat = 230
    /// A popover that scrolls, in a short window.
    static let countriesPopoverMaximumHeight: CGFloat = 360
    static let countriesNameColumnWidth: CGFloat = 190
    static let countriesDollarsColumnWidth: CGFloat = 70
    static let countriesSourceColumnWidth: CGFloat = 150
    static let countriesChangeColumnWidth: CGFloat = 200
    static let countriesFindFieldWidth: CGFloat = 260
    /// A product page narrower or shorter than these is at its smallest
    /// (860 × 560): name and base price in the breadcrumb row, a one-line
    /// banner, no filter counts, icon-only Filters and Columns, a floating
    /// inspector.
    static let productPageCompactWidth: CGFloat = 700
    static let productPageCompactHeight: CGFloat = 600
    static let countriesFindFieldMinimumWidth: CGFloat = 150
    /// The Filters popover.
    static let countriesFiltersWidth: CGFloat = 240
    /// A map tile's side and the gap between tiles.
    static let countriesMapTile: CGFloat = 30
    static let countriesMapGap: CGFloat = 2
    /// The histogram's plot.
    static let countriesHistogramHeight: CGFloat = 260
    /// The Accept All sheet.
    static let countriesAcceptAllWidth: CGFloat = 460
    /// The inspector floating over the table at 860 × 560.
    static let countriesFloatingInspectorHeight: CGFloat = 380
}
