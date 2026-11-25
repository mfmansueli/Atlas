//
//  GetAnalyticsRetentionTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsRetentionTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_retention",
        title: "Get retention analytics",
        description: """
        Reads what happens when people tap Cancel Subscription, from Apple's Retention Messaging report (every subscriber, \
        not a sample), over the last 7, 28 (default) or 90 complete days: how many opened the cancel screen, stayed and \
        canceled, the save rate (1 − cancels ÷ opened), each retention message's save rate against No Message (Apple's \
        plain screen, the reference), by subscription, and how people stayed (redeemed the offer, switched plan, tapped \
        Don't Cancel). With `by`, `rows` splits the same numbers by subscription, territory, device, offer or message \
        type, each with its save rate and whether a message keeps more people than none there. Apple completes a day up \
        to 4 days later: `through` is the last complete day. Use it before propose_retention_message and \
        propose_retention_offer, and never quote a rate marked tooFewToTell. Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "days": ["type": "integer", "description": "7, 28 or 90. Leave it out for 28."],
                "by": AnalyticsMCPBreakdown.schema(Self.breakdowns, leftOut: "Leave it out for the whole app only."),
            ],
            required: ["appId"]
        )
    )

    /// What `by` splits retention by.
    static let breakdowns = ["subscription", "territory", "device", "offer", "messageType"]

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let analytics = try await AnalyticsMCPContext.load(app: arguments.string("appId"), in: context.workspace, store: store)
        let breakdown = try AnalyticsMCPBreakdown.dimension(arguments, allowed: Self.breakdowns)
        guard let report = try RetentionReport.make(analytics.reports, days: AnalyticsMCPContext.days(arguments)) else {
            throw MCPToolError.unavailable(analytics.noRows(.retention))
        }
        var result: [String: JSONValue] = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "report": analytics.reportStatus(.retention),
            "period": AnalyticsMCPJSON.period(report.period),
            "stillArriving": report.arriving.map(AnalyticsMCPJSON.period) ?? .null,
            "openedCancelScreen": .int(report.opened),
            "stayed": .int(report.stayed),
            "canceled": .int(report.canceled),
            "saveRate": AnalyticsMCPJSON.rate(report.rate),
            "saveRateAgainstPrevious": AnalyticsMCPJSON.comparison(report.comparison),
            "withAMessage": AnalyticsMCPJSON.rate(report.withMessage),
            "noMessage": AnalyticsMCPJSON.rate(report.noMessage),
            "messageAgainstNoMessage": AnalyticsMCPContext.outcome(report.withAgainstWithout),
            "messages": .array(report.messages.map { message in
                [
                    "id": .string(message.id), "name": .string(message.name), "type": .string(message.type),
                    "isNoMessage": .bool(message.isNoMessage), "subscriptions": .array(message.subscriptions.map(JSONValue.string)),
                    "offer": message.offerName.map(JSONValue.string) ?? .null,
                    "opened": .int(message.opened), "stayed": .int(message.stayed),
                    "redeemedOffer": .int(message.redeemed), "switchedPlan": .int(message.switched),
                    "saveRate": AnalyticsMCPJSON.rate(message.rate),
                    "againstNoMessage": AnalyticsMCPContext.outcome(message.againstNoMessage),
                ]
            }),
            "subscriptions": .array(report.subscriptions.map { row in
                ["name": .string(row.name), "opened": .int(row.opened), "stayed": .int(row.stayed), "saveRate": AnalyticsMCPJSON.rate(row.rate)]
            }),
            "howTheyStayed": .array(report.saveTypes.map { ["how": .string($0.name), "count": .int($0.count)] }),
        ]
        if let breakdown {
            result["by"] = .string(breakdown.name)
            result["rows"] = Self.rows(analytics.reports.records(.retention).within(report.period), by: breakdown.dimension)
        }
        return .read(.object(result), target: "\(analytics.app.name) · Retention")
    }

    /// Each value's cancel-screen numbers: opened, stayed, the save rate,
    /// and (unless split by message type) a message against No Message.
    static func rows(_ records: [ReportRecord], by dimension: ReportDimension) -> JSONValue {
        .array(AnalyticsMCPBreakdown.names(records, dimension).map { name in
            let rows = records.filter { AnalyticsMCPBreakdown.key($0, dimension) == name }
            let total = RetentionReport.counts(rows)
            var row: [String: JSONValue] = [
                "name": .string(name), "opened": .int(total.opened), "stayed": .int(total.stayed),
                "canceled": .int(total.opened - total.stayed),
                "saveRate": AnalyticsMCPJSON.rate(AnalyticsStatistics.rate(count: total.stayed, total: total.opened)),
            ]
            if dimension != .messageType {
                let with = RetentionReport.counts(rows.filter { !RetentionReport.isNoMessage($0) })
                let without = RetentionReport.counts(rows.filter(RetentionReport.isNoMessage))
                row["messageAgainstNoMessage"] = without.opened > 0 && with.opened > 0
                    ? AnalyticsMCPContext.outcome(RetentionReport.groupComparison(with, against: without))
                    : .null
            }
            return .object(row)
        })
    }
}
