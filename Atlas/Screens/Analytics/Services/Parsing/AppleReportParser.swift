//
//  AppleReportParser.swift
//  Atlas
//

import Foundation

/// Reads one of Apple's newer report files into facts: the kind's kept
/// columns, by name, with the same spellings the funnel's reports use
/// (sources, pages, territories), and the rest added up.
enum AppleReportParser {
    static func facts(_ table: DelimitedTable, kind: AppleReportKind, appID: String?) -> [ReportFact] {
        let dateColumn = kind.dateColumns.first(where: table.has)
        let dimensions = kind.dimensions.map { dimension in (dimension, dimension.columnNames.first(where: table.has)) }
        let measures = kind.measures.map { measure in measure.columnNames.first(where: table.has) }
        var facts: [ReportFact] = []
        for row in table.rows {
            if let appID, table.has("App Apple Identifier"), table.value("App Apple Identifier", in: row) != appID { continue }
            guard let dateColumn, let day = AnalyticsDay(iso: String(table.value(dateColumn, in: row).prefix(10))) else { continue }
            let values = dimensions.map { dimension, column in
                column.map { normalized(table.value($0, in: row), as: dimension) } ?? ""
            }
            let counts = measures.map { column in column.map { table.int($0, in: row) } ?? 0 }
            guard counts.contains(where: { $0 != 0 }) else { continue }
            facts.append(ReportFact(day: day, values: values, counts: counts))
        }
        return ReportFact.merged(facts)
    }

    /// One spelling per meaning, so rows from different reports meet.
    static func normalized(_ value: String, as dimension: ReportDimension) -> String {
        switch dimension {
        case .territory: ReportTerritory.alpha2(value)
        case .source: EngagementReportParser.sourceName(value)
        case .page: EngagementReportParser.pageName(value)
        case .referrer, .campaign, .offerName, .suggested, .messageName, .messageID, .planChange, .cancelReason, .offerType:
            EngagementReportParser.named(value) ?? ""
        case .recentDownload: EngagementReportParser.named(value) == nil ? "" : "1"
        default: value.trimmingCharacters(in: .whitespaces)
        }
    }
}
