//
//  GetAnalyticsFunnelTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsFunnelTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_funnel",
        title: "Get the App Store funnel",
        description: """
        Reads an app's funnel from the reports Atlas downloaded from Apple: impressions → product page views → \
        first-time downloads → trial starts → paid starts, for the last 7, 28 (default) or 90 days and the same number of days \
        before. Each step has its count and its rate from the step before with a 90% range; `status: tooFewToTell` means the \
        numbers are too small for a rate, so don't quote one. `againstPrevious` says whether the rate moved for sure \
        (higherSure, lowerFairlySure, aboutTheSame…). Also returns the open findings and `notes` on what's missing: tell the \
        person those. Read-only; it answers from this Mac and never asks Apple. Follow with get_analytics_breakdown to find \
        where a step is weak, then propose the fix with the propose_ and suggest_ tools, and add_finding to say why.
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
        let report = try analytics.funnel(days: AnalyticsMCPContext.days(arguments))
        let findings = store.findings(for: analytics.app.id)
        let steps: [JSONValue] = report.steps.map { step in
            var object: [String: JSONValue] = [
                "step": .string(step.stage.rawValue),
                "count": AnalyticsMCPJSON.count(step.count),
                "previousCount": AnalyticsMCPJSON.count(report.previousTotals?.count(step.stage)),
            ]
            if let gap = step.gap { object["missing"] = .string(gap.text) }
            if step.stage.previous != nil {
                object["rateFromPreviousStep"] = AnalyticsMCPJSON.rate(step.rate)
                object["againstPrevious"] = AnalyticsMCPJSON.comparison(step.comparison)
            }
            return .object(object)
        }
        let result: JSONValue = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "period": AnalyticsMCPJSON.period(report.period),
            "previousPeriod": report.previous.map(AnalyticsMCPJSON.period) ?? .null,
            "steps": .array(steps),
            "proceedsUSD": AnalyticsMCPJSON.dollars(report.totals.proceeds),
            "summary": .string("\(report.callout.title). \(report.callout.text)"),
            "findings": .array(findings.open.map { AnalyticsMCPJSON.finding($0, state: findings) }),
            "notes": .array(analytics.notes),
        ]
        return .read(result, target: "\(analytics.app.name) · Funnel")
    }
}
