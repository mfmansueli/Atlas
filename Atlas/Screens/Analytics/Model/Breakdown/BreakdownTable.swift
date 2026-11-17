//
//  BreakdownTable.swift
//  Atlas
//

import Foundation

/// Break It Down for one dimension and period.
struct BreakdownTable: Hashable, Sendable {
    var dimension: BreakdownDimension
    var period: AnalyticsPeriod
    /// The whole app in the period: the averages rows are compared with.
    var totals: FunnelTotals
    var rows: [BreakdownRow]
    /// What's said once under the table: Apple's privacy threshold, how
    /// languages are derived, what isn't split this way.
    var footer: String

    func row(_ id: BreakdownRow.ID?) -> BreakdownRow? {
        rows.first { $0.id == id }
    }

    func sorted(by column: BreakdownColumn, ascending: Bool) -> [BreakdownRow] {
        if column == .name {
            let wanted: ComparisonResult = ascending ? .orderedAscending : .orderedDescending
            return rows.sorted { $0.name.localizedStandardCompare($1.name) == wanted }
        }
        return rows.sorted { lhs, rhs in
            switch (lhs.sortValue(column), rhs.sortValue(column)) {
            case let (left?, right?): left == right ? lhs.name < rhs.name : (ascending ? left < right : left > right)
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): lhs.name < rhs.name
            }
        }
    }
}
