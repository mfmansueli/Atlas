//
//  ReportRecord.swift
//  Atlas
//

import Foundation

/// One fact read through its report's columns: `record[.saveType]`,
/// `record.count(.sessions)`.
struct ReportRecord: Hashable, Sendable {
    let kind: AppleReportKind
    let fact: ReportFact

    var day: AnalyticsDay { fact.day }

    subscript(_ dimension: ReportDimension) -> String {
        guard let index = kind.dimensions.firstIndex(of: dimension), fact.values.indices.contains(index) else { return "" }
        return fact.values[index]
    }

    /// The value lowercased, for comparing with Apple's words.
    func lower(_ dimension: ReportDimension) -> String {
        self[dimension].lowercased()
    }

    func count(_ measure: ReportMeasure = .counts) -> Int {
        guard let index = kind.measures.firstIndex(of: measure), fact.counts.indices.contains(index) else { return 0 }
        return fact.counts[index]
    }
}

extension [ReportRecord] {
    func total(_ measure: ReportMeasure = .counts) -> Int {
        reduce(0) { $0 + $1.count(measure) }
    }

    func within(_ period: AnalyticsPeriod) -> [ReportRecord] {
        filter { period.contains($0.day) }
    }
}
