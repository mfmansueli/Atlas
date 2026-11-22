//
//  AnalyticsMCPContext+Reports.swift
//  Atlas
//

import Foundation

/// What the newer reports' tools share: where a report stands, and the
/// period they answer for.
extension AnalyticsMCPContext {
    var reports: ReportsArchive { dataset.reports }

    /// "ready" through a day, "noRows" (Apple sent it empty) or "asked".
    func reportStatus(_ kind: AppleReportKind) -> JSONValue {
        var object: [String: JSONValue] = ["report": .string(kind.title), "sample": .bool(kind.isSample)]
        switch reports.progress(kind).state {
        case let .ready(through):
            object["status"] = "ready"
            object["through"] = .string(through.iso)
        case .noRows:
            object["status"] = "noRows"
        case .asked:
            object["status"] = "asked"
        }
        return .object(object)
    }

    /// The reason a report's tool has nothing to say, for MCPToolError.
    func noRows(_ kind: AppleReportKind) -> String {
        switch reports.progress(kind).state {
        case .noRows: "Apple sent \(app.name)'s \(kind.title) report, but it has no rows yet."
        case .asked, .ready:
            "Apple hasn't sent \(app.name)'s \(kind.title) report yet. It comes with the same request as the funnel's; the first one usually takes 1 to 2 days after it's asked for."
        }
    }

    /// The last `days` days ending on the newest day any newer report has.
    func reportsPeriod(days: Int) -> AnalyticsPeriod? {
        AppleReportKind.allCases.compactMap { reports.lastDay($0) }.max().map { AnalyticsPeriod(ending: $0, length: days) }
    }

    static func outcome(_ outcome: ComparisonOutcome?) -> JSONValue {
        guard let outcome else { return .null }
        return switch outcome {
        case .tooFew: "tooFewToTell"
        case .same: "aboutTheSame"
        case .higher(.sure): "higherSure"
        case .higher(.fairlySure): "higherFairlySure"
        case .lower(.sure): "lowerSure"
        case .lower(.fairlySure): "lowerFairlySure"
        }
    }

    static func subscribers(_ counts: SubscriberCounts, average: Double? = nil) -> JSONValue {
        [
            "trials": .int(counts.trials), "paid": .int(counts.paid), "trialsEnded": .int(counts.trialsEnded),
            "trialToPaid": AnalyticsMCPJSON.rate(counts.trialToPaid(average: average)),
        ]
    }

    static func afterDownload(_ numbers: AfterDownloadNumbers) -> JSONValue {
        [
            "installs": .int(numbers.installs), "deletions": .int(numbers.deletions),
            "deletedWithin30Days": AnalyticsMCPJSON.rate(numbers.deletedWithin30),
            "sessions": .int(numbers.sessions),
            "sessionsPerWeekPerDevice": numbers.sessionsPerWeek.map { .double(($0 * 10).rounded() / 10) } ?? .null,
            "widgetDevices": .int(numbers.widgetDevices),
        ]
    }
}
