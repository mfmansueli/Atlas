//
//  Metrics+AnalyticsOverview.swift
//  Atlas
//

import CoreGraphics

/// Analytics → Overview's sizes (board 92, README-DS §16; design-tokens.json
/// → analyticsOverview): the narrowest a number card and a funnel step
/// card read at.
extension Metrics {
    /// One of the four numbers: four fit side by side at 860 pt with the
    /// sidebar open, two under that.
    static let analyticsKPIMinWidth: CGFloat = 128
    /// A funnel step card; under five of these and their chevrons the
    /// funnel scrolls sideways.
    static let analyticsFunnelCardMinWidth: CGFloat = 112
}
