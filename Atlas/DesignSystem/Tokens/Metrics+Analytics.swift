//
//  Metrics+Analytics.swift
//  Atlas
//

import CoreGraphics

/// Analytics' sizes (board 92, README-DS §16; design-tokens.json →
/// analytics): where Break It Down folds, how tall After Changes' chart is
/// and when its three results stack.
extension Metrics {
    /// Under this width Break It Down hides the counts (Impressions,
    /// Downloads, Starts) and the inspector slides over the table from the
    /// right instead of squeezing it.
    static let breakdownCompactWidth: CGFloat = 940
    /// After Changes' chart of the measured step around the push.
    static let changeChartHeight: CGFloat = 200
    /// Under this width of the result, its three numbers (the step, the
    /// counts, the difference) stack in one column: at 860 pt they do.
    static let changeResultsRowWidth: CGFloat = 640
    /// The Analytics tile at the start of the "From Analytics" bar.
    static let analyticsOriginTile: CGFloat = 22
}
