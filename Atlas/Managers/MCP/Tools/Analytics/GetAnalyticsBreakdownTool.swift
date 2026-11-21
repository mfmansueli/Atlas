//
//  GetAnalyticsBreakdownTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsBreakdownTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_breakdown",
        title: "Break the funnel down",
        description: """
        Splits an app's funnel by `by`: territory (default), language (the territories whose App Store shows that page), \
        source (App Store Search, Browse, App Referrer, Web Referrer…), device or productPage, for the last 7, 28 (default) or \
        90 days. Each row has its counts and three rates (viewRate = page views per impression, downloadRate = downloads per \
        page view, startRate = subscription starts per download) with `againstAverage` better/worse/same, said only when the \
        rate's whole 90% range is above or below the app's average. Territory rows also say which language's page they see, \
        whether that page is machine-translated or missing, and the price against purchasing power when known. Apple doesn't \
        link subscriptions to a source or a product page: those are null there. Rows are sorted by impressions; `limit` \
        (default 40) keeps the largest. Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "by": MCPToolDefinition.string(
                    "territory, language, source, device, productPage, referrer (the app or website people came from) "
                        + "or campaign (a campaign link's ct token). Leave it out for territory."
                ),
                "days": ["type": "integer", "description": "7, 28 or 90. Leave it out for 28."],
                "limit": ["type": "integer", "description": "The most rows to return. Leave it out for 40."],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let analytics = try await AnalyticsMCPContext.load(app: arguments.string("appId"), in: context.workspace, store: store)
        let report = try analytics.funnel(days: AnalyticsMCPContext.days(arguments))
        let name = try arguments.optionalString("by") ?? BreakdownDimension.territory.rawValue
        guard let dimension = BreakdownDimension(rawValue: name) else {
            throw MCPToolError.invalidArgument(name: "by", expected: "territory, language, source, device, productPage, referrer or campaign")
        }
        let limit = try max(1, arguments.optionalInt("limit") ?? 40)
        let table = BreakdownTable.make(analytics.dataset, dimension: dimension, period: report.period, context: analytics.context)
        let rows: [JSONValue] = table.rows.prefix(limit).map { row in
            var object = AnalyticsMCPJSON.totals(row.totals)
            object["id"] = .string(row.id)
            object["name"] = .string(row.name)
            object["viewRate"] = AnalyticsMCPJSON.rate(row.viewRate)
            object["downloadRate"] = AnalyticsMCPJSON.rate(row.downloadRate)
            object["startRate"] = AnalyticsMCPJSON.rate(row.startRate)
            if dimension == .territory {
                if let locale = analytics.context.locale(for: row.id) { object["pageLocale"] = .string(locale.code) }
                if let state = analytics.context.textState(for: row.id) { object["pageText"] = .string(state.rawValue) }
                if let price = analytics.context.prices[row.id] {
                    object["price"] = ["now": .string(price.priceText), "purchasingPower": .string(price.suggestedText), "ratio": .double(price.ratio)]
                }
            }
            return .object(object)
        }
        let result: JSONValue = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "by": .string(dimension.rawValue),
            "period": AnalyticsMCPJSON.period(table.period),
            "all": .object(AnalyticsMCPJSON.totals(table.totals)),
            "rows": .array(rows),
            "rowsLeftOut": .int(max(0, table.rows.count - limit)),
            "notes": .array(analytics.notes + [.string(table.footer)]),
        ]
        return .read(result, target: "\(analytics.app.name) · Breakdown by \(dimension.title)")
    }
}
