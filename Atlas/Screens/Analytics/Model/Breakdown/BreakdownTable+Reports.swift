//
//  BreakdownTable+Reports.swift
//  Atlas
//

import Foundation

/// Subscribers and after-download numbers per row, from Apple's newer
/// reports, for the dimensions they name: territory, device, source,
/// product page and campaign.
extension BreakdownTable {
    /// Whether Apple's newer reports split this dimension.
    static func reportsSplit(_ dimension: BreakdownDimension) -> Bool {
        switch dimension {
        case .territory, .device, .source, .productPage, .campaign: true
        case .language, .referrer: false
        }
    }

    mutating func addReports(_ reports: ReportsArchive) {
        guard Self.reportsSplit(dimension), !reports.isEmpty else { return }
        let hasSubscribers = reports.hasRows(.subscriptionEvents)
        let hasAfter = reports.hasRows(.installs) || reports.hasRows(.sessions)
        guard hasSubscribers || hasAfter else { return }
        let all = reports.subscribers(in: period) { _ in true }
        let average = all.trialToPaidFraction
        let allAfter = AfterDownloadNumbers.make(reports, period: period)
        subscribers = hasSubscribers ? all : nil
        afterDownload = hasAfter ? allAfter : nil
        // The new columns link subscribers to the rows: the footer says so
        // instead of "Subscriptions aren't linked".
        footer = Self.footer(dimension, hasSales: true, linksSubscribers: hasSubscribers, hasSample: hasAfter)
        let dimension = dimension
        rows = rows.map { row in
            var row = row
            let matches: (ReportRecord) -> Bool = { record in Self.record(record, isIn: row, dimension: dimension) }
            if hasSubscribers {
                let counts = reports.subscribers(in: period, matching: matches)
                row.subscribers = counts
                row.trialToPaid = counts.trialToPaid(average: average)
            }
            if hasAfter {
                let numbers = AfterDownloadNumbers.make(reports, period: period, matching: matches)
                row.afterDownload = numbers
                // No ▲▼ against the average: a higher rate here is worse.
                row.deleted30 = numbers.deletedWithin30
            }
            return row
        }
    }

    private static func record(_ record: ReportRecord, isIn row: BreakdownRow, dimension: BreakdownDimension) -> Bool {
        switch dimension {
        case .territory: record[.territory] == row.id
        case .device: record[.device] == row.id
        case .source: record[.source] == row.id
        case .productPage: ReportsArchive.pageName(record, defaultName: ProductPageNumbers.defaultPageName) == row.name
        case .campaign: record[.campaign] == row.name
        case .language, .referrer: false
        }
    }
}
