//
//  BreakdownColumnLayout.swift
//  Atlas
//

import SwiftUI

/// The breakdown table's columns and their widths. Under
/// `Metrics.breakdownCompactWidth`, or with the inspector open beside the
/// table, the counts behind the rates (Impressions, Downloads, Starts) move
/// into the inspector, and the table keeps page views, the three rates and
/// proceeds.
struct BreakdownColumnLayout: Equatable {
    var isCompact: Bool
    var hasSales: Bool
    var group = BreakdownColumnGroup.funnel
    /// The column with the accent's tint: Proceeds, from the Overview's
    /// Proceeds number.
    var highlighted: BreakdownColumn?

    /// The layout for Break It Down `width` wide.
    static func make(
        width: CGFloat, hasInspector: Bool, hasSales: Bool, group: BreakdownColumnGroup = .funnel, highlighted: BreakdownColumn? = nil
    ) -> BreakdownColumnLayout {
        BreakdownColumnLayout(
            isCompact: hasInspector || isNarrow(width), hasSales: hasSales, group: group, highlighted: highlighted
        )
    }

    /// Under `Metrics.breakdownCompactWidth`: the counts hide, and the
    /// inspector slides over the table instead of sitting beside it.
    static func isNarrow(_ width: CGFloat) -> Bool {
        width < Metrics.breakdownCompactWidth
    }

    /// Whether the inspector covers the table's right side rather than
    /// taking room beside it.
    static func inspectorOverlays(width: CGFloat) -> Bool {
        isNarrow(width)
    }

    var columns: [BreakdownColumn] {
        BreakdownColumn.allCases.filter { column in
            if column == .name || !column.isShown(in: group) { return false }
            if isCompact, column.isCount { return false }
            return true
        }
    }

    func isHighlighted(_ column: BreakdownColumn) -> Bool {
        highlighted == column
    }

    /// The name column never gets narrower than this.
    static let nameMinimum: CGFloat = 110

    func width(of column: BreakdownColumn) -> CGFloat {
        switch column {
        case .name: 0
        case .impressions, .pageViews, .downloads: isCompact ? 72 : 82
        case .starts: 60
        case .viewRate, .downloadRate, .startRate: isCompact ? 92 : 104
        case .proceeds: 78
        case .trials, .paid: 64
        case .trialToPaid, .deleted30: isCompact ? 92 : 110
        case .sessionsPerWeek: 92
        }
    }
}
