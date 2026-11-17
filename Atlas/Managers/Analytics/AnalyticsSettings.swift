//
//  AnalyticsSettings.swift
//  Atlas
//

import Foundation

/// Analytics' settings and what it remembers per app, as one file.
struct AnalyticsSettings: Hashable, Sendable, Codable {
    /// The team's vendor number, for Sales and Trends; "" until typed in.
    var vendorNumber = ""
    var refreshMode = AnalyticsRefreshMode.everyMorning
    /// A sales read was refused: the key's role can't read Sales and Trends.
    var keyCannotReadSales = false
    var records: [String: AnalyticsAppRecord] = [:]
    var findings: [String: AnalyticsFindingsState] = [:]
}
