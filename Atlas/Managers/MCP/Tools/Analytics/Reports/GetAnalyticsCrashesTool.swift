//
//  GetAnalyticsCrashesTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsCrashesTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_crashes",
        title: "Get crashes by version",
        description: """
        Reads Apple's App Crashes and App Sessions reports (a sample: people who share analytics with developers; days \
        complete up to 5 days later): crashes per 1,000 sessions of the newest version against the one before on the \
        same days, whether the newest is clearly worse (`againstPrevious`), by device, and by day. Use it to find what to \
        fix in the code; say it's a sample. Read-only: pausing a phased release is the person's decision, in Atlas.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let analytics = try await AnalyticsMCPContext.load(app: arguments.string("appId"), in: context.workspace, store: store)
        guard let report = StabilityReport.make(analytics.reports, now: AnalyticsDay(analytics.store.now())) else {
            throw MCPToolError.unavailable(analytics.noRows(.sessions))
        }
        func version(_ numbers: StabilityReport.VersionNumbers) -> JSONValue {
            [
                "version": .string(numbers.version), "crashes": .int(numbers.crashes), "sessions": .int(numbers.sessions),
                "crashesPer1000Sessions": numbers.perThousand.map { .double(($0 * 10).rounded() / 10) } ?? .null,
            ]
        }
        let result: JSONValue = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "reports": .array([analytics.reportStatus(.crashes), analytics.reportStatus(.sessions)]),
            "period": AnalyticsMCPJSON.period(report.period),
            "latest": version(report.latest),
            "previous": report.previous.map(version) ?? .null,
            "againstPrevious": AnalyticsMCPContext.outcome(report.comparison),
            "times": report.times.map { .double(($0 * 10).rounded() / 10) } ?? .null,
            "byDevice": .array(report.devices.map { row in
                ["device": .string(row.device), "latest": version(row.latest), "previous": row.previous.map(version) ?? .null]
            }),
            "byDay": .array(report.days.map { day in
                [
                    "day": .string(day.day.iso),
                    "latest": day.latest.map { .double(($0 * 10).rounded() / 10) } ?? .null,
                    "previous": day.previous.map { .double(($0 * 10).rounded() / 10) } ?? .null,
                ]
            }),
        ]
        return .read(result, target: "\(analytics.app.name) · Crashes")
    }
}
