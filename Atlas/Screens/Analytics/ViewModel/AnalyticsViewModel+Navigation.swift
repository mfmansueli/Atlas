//
//  AnalyticsViewModel+Navigation.swift
//  Atlas
//

import Foundation

extension AnalyticsViewModel {
    /// The Overview's Proceeds KPI → "By Country": Break It Down by
    /// territory, sorted by proceeds, with the proceeds banner.
    func showProceedsByCountry() {
        dimension = .territory
        if !BreakdownColumn.proceeds.isShown(in: columnGroup) {
            columnGroup = BreakdownColumnGroup.allCases.first { BreakdownColumn.proceeds.isShown(in: $0) } ?? columnGroup
        }
        sortColumn = .proceeds
        sortAscending = false
        showsProceedsBanner = true
        tab = .breakDown
    }
}
