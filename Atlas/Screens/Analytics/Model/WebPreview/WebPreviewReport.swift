//
//  WebPreviewReport.swift
//  Atlas
//

import Foundation

/// The app's page on apps.apple.com: how many saw it in a browser and what
/// they tapped, from Apple's App Store Web Preview report.
struct WebPreviewReport: Hashable, Sendable {
    struct Tap: Hashable, Sendable, Identifiable {
        var name: String
        var count: Int
        var share: Double

        var id: String { name }
    }

    var period: AnalyticsPeriod
    var pageViews: Int
    var taps: Int
    var byEngagement: [Tap]

    /// nil without a row in `period`.
    static func make(_ reports: ReportsArchive, period: AnalyticsPeriod) -> WebPreviewReport? {
        let records = reports.records(.webPreview).within(period)
        guard !records.isEmpty else { return nil }
        let views = records.filter { $0.lower(.event).contains("view") }
        let taps = records.filter { $0.lower(.event).contains("tap") }
        let total = taps.total()
        let byEngagement = Dictionary(grouping: taps) { $0[.engagementType].isEmpty ? String(localized: "Other") : $0[.engagementType] }
            .map { name, records in Tap(name: name, count: records.total(), share: total > 0 ? Double(records.total()) / Double(total) : 0) }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
        return WebPreviewReport(period: period, pageViews: views.total(), taps: total, byEngagement: byEngagement)
    }
}
