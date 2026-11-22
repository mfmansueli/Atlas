//
//  GetAnalyticsWebPreviewTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsWebPreviewTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_web_preview",
        title: "Get the app's page on the web",
        description: """
        Reads Apple's App Store Web Preview report for the last 7, 28 (default) or 90 days: how many saw the app's page on \
        apps.apple.com in a browser, and what they tapped there (reviews, privacy details, the developer's website…). \
        Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "days": ["type": "integer", "description": "7, 28 or 90. Leave it out for 28."],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let analytics = try await AnalyticsMCPContext.load(app: arguments.string("appId"), in: context.workspace, store: store)
        guard let period = try analytics.reportsPeriod(days: AnalyticsMCPContext.days(arguments)),
              let report = WebPreviewReport.make(analytics.reports, period: period)
        else { throw MCPToolError.unavailable(analytics.noRows(.webPreview)) }
        let result: JSONValue = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "report": analytics.reportStatus(.webPreview),
            "period": AnalyticsMCPJSON.period(report.period),
            "pageViews": .int(report.pageViews),
            "taps": .int(report.taps),
            "byTap": .array(report.byEngagement.map { ["what": .string($0.name), "count": .int($0.count)] }),
        ]
        return .read(result, target: "\(analytics.app.name) · Web preview")
    }
}
