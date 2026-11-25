//
//  Metrics+Skeleton.swift
//  Atlas
//

import CoreGraphics

/// The skeletons' sizes (design-tokens.json → skeleton; the prototype's
/// lib-loading, a11y-loading, cp-loading and pricing-skeleton scenes).
extension Metrics {
    /// A text line, its shorter second line, a card's body line and a
    /// card's title line.
    static let skeletonLine: CGFloat = 9
    static let skeletonCaptionLine: CGFloat = 7
    static let skeletonBodyLine: CGFloat = 10
    static let skeletonTitleLine: CGFloat = 12
    /// A list row with an icon and two lines (the sidebar's apps), and its icon.
    static let skeletonListRowHeight: CGFloat = 48
    static let skeletonIcon: CGFloat = 30
    /// A card while it loads (Accessibility's family cards).
    static let skeletonCardHeight: CGFloat = 150
    /// A table row's cell, its name and its flag.
    static let skeletonCellWidth: CGFloat = 70
    static let skeletonNameWidth: CGFloat = 120
    static let skeletonFlagWidth: CGFloat = 20
    static let skeletonFlagHeight: CGFloat = 13
    /// A screenshot tile in a set's row, and its height ÷ width (iPhone).
    static let skeletonTileWidth: CGFloat = 34
    static let skeletonTileAspect: CGFloat = 2.16
    /// Overview's title line and its cards while the summaries load.
    static let skeletonOverviewTitle: CGFloat = 28
    static let skeletonOverviewTitleWidth: CGFloat = 260
    static let skeletonOverviewCardHeight: CGFloat = 120
    /// Store Page's coverage rows and their field cells.
    static let skeletonStorePageRowHeight: CGFloat = 32
    static let skeletonStorePageCellWidth: CGFloat = 52
    /// A language page's screenshot tile while its live set is read.
    static let skeletonHandTileWidth: CGFloat = 72
    /// An In-App Event's card while the events are read.
    static let skeletonEventCardHeight: CGFloat = 230
    /// A review's or a nomination's card in a list, and Reviews' side card.
    static let skeletonRowCardHeight: CGFloat = 96
    static let skeletonReviewsSideHeight: CGFloat = 180
    /// A privacy URL's cell.
    static let skeletonURLCellWidth: CGFloat = 200
    /// Analytics' funnel stages while the first reports download, and the
    /// card that lists them.
    static let skeletonFunnelStageHeight: CGFloat = 84
    static let skeletonAnalyticsCardWidth: CGFloat = 420
    /// A build's row in Submit for Review.
    static let skeletonBuildRowHeight: CGFloat = 30
    /// A file's row in the Asset Library, and its thumbnail.
    static let skeletonAssetRowHeight: CGFloat = 56
    static let skeletonAssetThumbnailWidth: CGFloat = 72
    static let skeletonAssetThumbnailHeight: CGFloat = 44
    /// A plan's row on the paywall.
    static let skeletonPlanRowHeight: CGFloat = 54
}
