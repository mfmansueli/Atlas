//
//  ChangeResultLayout.swift
//  Atlas
//

import CoreGraphics

/// How a change's result lays out at a width (board 92): the three
/// results (the step, the counts, the difference) side by side, or in one
/// column under `Metrics.changeResultsRowWidth` (so at 860 pt), over a
/// chart `Metrics.changeChartHeight` tall.
enum ChangeResultLayout {
    static func stacksResults(width: CGFloat) -> Bool {
        width < Metrics.changeResultsRowWidth
    }

    static var chartHeight: CGFloat { Metrics.changeChartHeight }
}
