//
//  BreakdownColumnLayout.swift
//  Atlas
//

import SwiftUI

/// The breakdown table's columns and their widths. With the inspector
/// open (or a narrow window) the counts behind the rates move into the
/// inspector, and the table keeps page views, the three rates and proceeds.
struct BreakdownColumnLayout: Equatable {
    var isCompact: Bool
    var hasSales: Bool

    var columns: [BreakdownColumn] {
        BreakdownColumn.allCases.filter { column in
            if column == .name { return false }
            if isCompact, column.isCount { return false }
            return true
        }
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
        }
    }
}
