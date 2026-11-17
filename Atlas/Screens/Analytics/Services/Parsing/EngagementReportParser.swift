//
//  EngagementReportParser.swift
//  Atlas
//

import Foundation

/// Reads Apple's "App Store Discovery and Engagement" and "App Store
/// Downloads" files (Standard or Detailed) into engagement facts.
enum EngagementReportParser {
    /// Page types whose page views are product page views: the page in the
    /// App Store, and the sheet other apps show.
    private static let productPageTypes: Set<String> = ["product page", "store sheet"]

    /// Impressions and product page views, per day and dimension.
    static func engagement(_ table: DelimitedTable, appID: String?) -> [EngagementFact] {
        var facts: [EngagementFact] = []
        for row in table.rows {
            guard let fact = base(table, row, appID: appID) else { continue }
            var counted = fact
            let count = table.int("Counts", in: row)
            switch table.value("Event", in: row).lowercased() {
            case "impression":
                counted.impressions = count
            case "page view" where productPageTypes.contains(table.value("Page Type", in: row).lowercased()):
                counted.pageViews = count
            default:
                continue
            }
            facts.append(counted)
        }
        return EngagementFact.merged(facts)
    }

    /// First-time downloads and redownloads; updates and restores aren't
    /// part of the funnel.
    static func downloads(_ table: DelimitedTable, appID: String?) -> [EngagementFact] {
        var facts: [EngagementFact] = []
        for row in table.rows {
            guard let fact = base(table, row, appID: appID) else { continue }
            var counted = fact
            let count = table.int("Counts", in: row)
            switch table.value("Download Type", in: row).lowercased() {
            case "first-time download": counted.downloads = count
            case "redownload": counted.redownloads = count
            default: continue
            }
            facts.append(counted)
        }
        return EngagementFact.merged(facts)
    }

    /// The row's day and dimensions; nil for another app's row or a row
    /// without a date.
    private static func base(_ table: DelimitedTable, _ row: [String], appID: String?) -> EngagementFact? {
        if let appID, table.has("App Apple Identifier"), table.value("App Apple Identifier", in: row) != appID { return nil }
        guard let day = AnalyticsDay(iso: table.value("Date", in: row)) else { return nil }
        return EngagementFact(
            day: day,
            territory: ReportTerritory.alpha2(table.value("Territory", in: row)),
            source: sourceName(table.value("Source Type", in: row)),
            device: table.value("Device", in: row),
            page: pageName(table.value("Page Title", in: row))
        )
    }

    /// Apple's casing differs between reports ("App Store search", "App
    /// Store Search"): one spelling, so the two reports' rows meet.
    static func sourceName(_ value: String) -> String {
        switch value.lowercased() {
        case "app store search": "App Store Search"
        case "app store browse": "App Store Browse"
        case "app referrer": "App Referrer"
        case "web referrer": "Web Referrer"
        case "institutional purchase": "Institutional"
        case "app clip": "App Clip"
        case "", "unavailable", "null": "Unavailable"
        default: value
        }
    }

    /// "" for the Standard reports; the Detailed ones name the default
    /// page in lowercase or leave it null.
    static func pageName(_ value: String) -> String {
        switch value.lowercased() {
        case "": ""
        case "default product page": "Default product page"
        case "null", "no page": "No page"
        default: value
        }
    }
}
