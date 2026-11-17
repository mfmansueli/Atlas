//
//  AnalyticsMCPJSON.swift
//  Atlas
//

import Foundation

/// How the analytics tools write numbers: counts, and each rate with its
/// 90% range and whether it means anything.
enum AnalyticsMCPJSON {
    static func rate(_ rate: AnalyticsRate) -> JSONValue {
        switch rate {
        case .missing:
            return ["status": "missing"]
        case let .tooFew(count, total):
            return ["status": "tooFewToTell", "count": .int(count), "of": .int(total)]
        case let .measured(measured):
            var object: [String: JSONValue] = [
                "status": "measured",
                "rate": .double(rounded(measured.value)),
                "count": .int(measured.count),
                "of": .int(measured.total),
                "low90": .double(rounded(measured.low)),
                "high90": .double(rounded(measured.high)),
                "sureness": .string(measured.bars == 3 ? "sure" : measured.bars == 2 ? "fairlySure" : "rough"),
            ]
            if let standing = measured.standing { object["againstAverage"] = .string(standing.rawValue) }
            return .object(object)
        }
    }

    static func comparison(_ comparison: PeriodComparison?) -> JSONValue {
        guard let comparison else { return .null }
        let outcome = switch comparison.outcome {
        case .tooFew: "tooFewToTell"
        case .same: "aboutTheSame"
        case .higher(.sure): "higherSure"
        case .higher(.fairlySure): "higherFairlySure"
        case .lower(.sure): "lowerSure"
        case .lower(.fairlySure): "lowerFairlySure"
        }
        var object: [String: JSONValue] = ["outcome": .string(outcome)]
        if let points = comparison.points { object["points"] = .double((points * 100).rounded() / 100) }
        return .object(object)
    }

    static func count(_ value: Int?) -> JSONValue {
        value.map(JSONValue.int) ?? .null
    }

    static func dollars(_ value: Decimal?) -> JSONValue {
        value.map { .double((NSDecimalNumber(decimal: $0).doubleValue * 100).rounded() / 100) } ?? .null
    }

    static func period(_ period: AnalyticsPeriod) -> JSONValue {
        ["from": .string(period.first.iso), "through": .string(period.last.iso), "days": .int(period.length)]
    }

    static func totals(_ totals: FunnelTotals) -> [String: JSONValue] {
        [
            "impressions": count(totals.impressions),
            "pageViews": count(totals.pageViews),
            "downloads": count(totals.downloads),
            "trialStarts": count(totals.trials),
            "paidStarts": count(totals.paid),
            "subscriptionStarts": count(totals.starts),
            "proceedsUSD": dollars(totals.proceeds),
        ]
    }

    static func finding(_ finding: AnalyticsFinding, state: AnalyticsFindingsState) -> JSONValue {
        [
            "id": .string(finding.id),
            "source": .string(finding.source.title),
            "area": .string(finding.area.rawValue),
            "title": .string(finding.title),
            "why": .string(finding.why),
            "howSure": .string(finding.surenessDetail),
            "isNew": .bool(state.isNew(finding)),
        ]
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 10000).rounded() / 10000
    }
}
