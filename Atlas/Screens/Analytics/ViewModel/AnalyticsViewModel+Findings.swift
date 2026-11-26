//
//  AnalyticsViewModel+Findings.swift
//  Atlas
//

import Foundation

extension AnalyticsViewModel {
    /// What What to Try shows: the lists, or why there's nothing in them.
    var findingsListState: FindingsListState {
        var isQuiet = false
        if case .tooFew = funnel?.callout.kind { isQuiet = true }
        return FindingsListState.make(
            dayCount: dataset.dayCount,
            firstDay: dataset.firstDay,
            isQuiet: isQuiet,
            findingCount: findings.open.count + findings.dismissed.count
        )
    }

    /// How many findings each of What to Try's lists holds.
    func findingsCount(_ filter: FindingsFilter) -> Int {
        switch filter {
        case .open: openFindings.count
        case .actedOn: actedFindings.count
        case .dismissed: findings.dismissed.count
        }
    }
}
