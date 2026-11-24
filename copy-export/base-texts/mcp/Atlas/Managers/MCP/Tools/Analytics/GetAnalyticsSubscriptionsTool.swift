//
//  GetAnalyticsSubscriptionsTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsSubscriptionsTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_subscriptions",
        title: "Get subscription analytics",
        description: """
        Reads an app's subscriptions from Sales and Trends, for the last 7, 28 (default) or 90 days: active subscribers, \
        trial → paid (of the trials that ended in the period), proceeds in US dollars after Apple's commission and taxes, \
        refunds, renewal rates by renewal (1st, 2nd, 3rd and later), cancellations by Apple's reason and how many came before \
        the first renewal, and trial → paid per subscription and per territory. Rates carry a 90% range and \
        `status: tooFewToTell` when they're too small to quote. Use it before propose_prices, propose_retention_message and \
        propose_in_app_texts. Read-only; needs the vendor number and a key that can read sales, and says so when it can't.
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
        let funnel = try analytics.funnel(days: AnalyticsMCPContext.days(arguments))
        guard let report = SubscriptionsReport.make(analytics.dataset, period: funnel.period) else {
            let reason = analytics.notes.dropFirst().compactMap { note -> String? in
                if case let .string(text) = note { return text }
                return nil
            }
            .joined(separator: " ")
            throw MCPToolError.unavailable(String(localized: "Atlas has no subscription numbers for \(analytics.app.name). \(reason)"))
        }
        let result: JSONValue = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "period": AnalyticsMCPJSON.period(report.period),
            "activeSubscribers": AnalyticsMCPJSON.count(report.active),
            "trialToPaid": AnalyticsMCPJSON.rate(report.trialToPaid),
            "trialToPaidAgainstPrevious": AnalyticsMCPJSON.comparison(report.trialToPaidComparison),
            "proceedsUSD": AnalyticsMCPJSON.dollars(report.proceeds),
            "refunds": .int(report.refunds),
            "charges": .int(report.charges),
            "renewals": .array(report.renewals.map { renewal in
                [
                    "subscription": .string(renewal.subscription), "renewal": .int(renewal.index), "renewed": .int(renewal.renewed),
                    "due": .int(renewal.due), "rate": AnalyticsMCPJSON.rate(renewal.rate),
                ]
            }),
            "cancellations": [
                "total": .int(report.cancellations),
                "beforeFirstRenewal": .int(report.earlyCancellations),
                "reasons": .array(report.reasons.filter { $0.count > 0 }.map { ["reason": .string($0.name), "count": .int($0.count)] }),
            ],
            "liveRetentionMessages": AnalyticsMCPJSON.count(analytics.context.liveRetentionMessages),
            "subscriptions": .array(report.products.map { product in
                [
                    "name": .string(product.name), "active": AnalyticsMCPJSON.count(product.active),
                    "trialToPaid": AnalyticsMCPJSON.rate(product.trialToPaid), "proceedsUSD": AnalyticsMCPJSON.dollars(product.proceeds),
                ]
            }),
            "territories": .array(report.territories.prefix(40).map { row in
                ["territory": .string(row.code), "name": .string(row.name), "trialToPaid": AnalyticsMCPJSON.rate(row.trialToPaid)]
            }),
            "notes": .array(analytics.notes),
        ]
        return .read(result, target: "\(analytics.app.name) · Subscriptions")
    }
}
