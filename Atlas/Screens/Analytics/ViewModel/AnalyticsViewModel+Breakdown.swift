//
//  AnalyticsViewModel+Breakdown.swift
//  Atlas
//

import Foundation

extension AnalyticsViewModel {
    /// The person picked a split: the proceeds banner belongs to the
    /// territories it was opened on, so it goes.
    func choose(_ dimension: BreakdownDimension) {
        showsProceedsBanner = false
        self.dimension = dimension
    }

    /// The proceeds banner's ✕.
    func closeProceedsBanner() {
        showsProceedsBanner = false
    }

    /// The proceeds banner's explanation, while it shows: from the
    /// Overview's Proceeds number, on the territories, with proceeds.
    var proceedsBannerText: String? {
        guard showsProceedsBanner, dimension == .territory, let table else { return nil }
        return BreakdownProceedsText.explanation(table)
    }

    /// The column the banner points at, tinted while it shows.
    var highlightedColumn: BreakdownColumn? {
        proceedsBannerText == nil ? nil : .proceeds
    }

    /// Opens the inspector on a row, or closes it when it's the open one.
    func toggleRow(_ id: BreakdownRow.ID) {
        selectedRowID = selectedRowID == id ? nil : id
    }
}
