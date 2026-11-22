//
//  AfterDownloadNumbers.swift
//  Atlas
//

import Foundation

/// What people do after the download, for one slice (the whole app, a
/// product page, a campaign, a source), from Apple's Installations and
/// Deletions, App Sessions and widget reports. Each counts only people who
/// share analytics with developers: a sample, so rates matter more than
/// counts.
struct AfterDownloadNumbers: Hashable, Sendable {
    /// First-time downloads and redownloads that were installed.
    var installs = 0
    var deletions = 0
    /// Deletions of an app downloaded in the 30 days before (Apple fills App
    /// Download Date only then).
    var recentDeletions = 0
    var sessions = 0
    /// Active devices, added up per day.
    var deviceDays = 0
    var sessionSeconds = 0
    var widgetDevices = 0
    var days = 0

    /// Deleted within 30 days of the download, per install.
    var deletedWithin30: AnalyticsRate {
        AnalyticsStatistics.rate(count: min(recentDeletions, installs), total: installs)
    }

    /// Sessions a week per active device.
    var sessionsPerWeek: Double? {
        deviceDays > 0 ? Double(sessions) / Double(deviceDays) * 7 : nil
    }

    /// Of the devices that installed, how many added a widget.
    var widgetShare: AnalyticsRate {
        AnalyticsStatistics.rate(count: min(widgetDevices, installs), total: installs)
    }

    var isEmpty: Bool { installs == 0 && deletions == 0 && sessions == 0 }

    /// The numbers for `period`, of the rows `matching` lets through.
    static func make(
        _ reports: ReportsArchive, period: AnalyticsPeriod, matching: (ReportRecord) -> Bool = { _ in true }
    ) -> AfterDownloadNumbers {
        var numbers = AfterDownloadNumbers(days: period.length)
        for record in reports.records(.installs).within(period) where matching(record) {
            let event = record.lower(.event)
            if event.hasPrefix("install") {
                let type = record.lower(.downloadType)
                if type.isEmpty || type.contains("first") || type.contains("redownload") { numbers.installs += record.count() }
            } else if event.hasPrefix("delete") {
                numbers.deletions += record.count()
                if !record[.recentDownload].isEmpty { numbers.recentDeletions += record.count() }
            }
        }
        for record in reports.records(.sessions).within(period) where matching(record) {
            numbers.sessions += record.count(.sessions)
            numbers.deviceDays += record.count(.uniqueDevices)
            numbers.sessionSeconds += record.count(.duration)
        }
        for record in reports.records(.widgets).within(period) where matching(record) {
            numbers.widgetDevices += record.count(.uniqueDevices) > 0 ? record.count(.uniqueDevices) : record.count()
        }
        return numbers
    }
}
