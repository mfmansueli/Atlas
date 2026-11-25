//
//  BreakdownInspectorFacts.swift
//  Atlas
//

import Foundation

/// The inspector's facts beyond a territory's: what a source is and what
/// people see there, and which languages a device's set covers.
enum BreakdownInspectorFacts {
    struct Fact: Hashable {
        var label: String
        var value: String
        var isWarning = false
    }

    /// Apple's name for search in the reports' Source column.
    static let search = "App Store Search"
    static let browse = "App Store Browse"

    static func extra(for row: BreakdownRow, dimension: BreakdownDimension, context: AnalyticsContext) -> [Fact] {
        switch dimension {
        case .source: sourceFacts(row)
        case .device: deviceFacts(row, context: context)
        default: []
        }
    }

    private static func sourceFacts(_ row: BreakdownRow) -> [Fact] {
        var facts: [Fact] = []
        if let detail = row.detail { facts.append(Fact(label: String(localized: "What it is", comment: "kind:label"), value: detail)) }
        let seen: String? = switch row.id {
        case search: String(localized: "Name, subtitle, rating and the first three screenshots", comment: "kind:label")
        case browse: String(localized: "The icon, name, subtitle and, in some places, the App Preview", comment: "kind:label")
        default: nil
        }
        if let seen { facts.append(Fact(label: String(localized: "What people see", comment: "kind:label"), value: seen)) }
        return facts
    }

    private static func deviceFacts(_ row: BreakdownRow, context: AnalyticsContext) -> [Fact] {
        guard let summary = context.screenshotCoverage?.summary(forReportDevice: row.id) else { return [] }
        return [Fact(label: String(localized: "Screenshots"), value: summary.text, isWarning: summary.isWarning)]
    }
}
