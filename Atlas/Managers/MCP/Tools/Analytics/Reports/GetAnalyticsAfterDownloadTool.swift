//
//  GetAnalyticsAfterDownloadTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsAfterDownloadTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_after_download",
        title: "Get what people do after the download",
        description: """
        Reads Apple's Installations and Deletions, App Sessions and Home Screen Widget Installs reports (a sample: people \
        who share analytics with developers) for the last 7, 28 (default) or 90 days: installs, deletions, the share \
        deleted within 30 days of the download, sessions a week per active device and devices that added a widget, for \
        the whole app and by product page, source, campaign and app version. With `by`, `rows` replaces those lists \
        with one split: by product page, source, campaign, app version, territory or device. Rates matter more than \
        counts here. Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "days": ["type": "integer", "description": "7, 28 or 90. Leave it out for 28."],
                "by": AnalyticsMCPBreakdown.schema(
                    Self.breakdowns, leftOut: "Leave it out for product page, source, campaign and app version."
                ),
            ],
            required: ["appId"]
        )
    )

    /// What `by` splits the numbers by.
    static let breakdowns = ["productPage", "source", "campaign", "appVersion", "territory", "device"]

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let analytics = try await AnalyticsMCPContext.load(app: arguments.string("appId"), in: context.workspace, store: store)
        let breakdown = try AnalyticsMCPBreakdown.dimension(arguments, allowed: Self.breakdowns)
        let reports = analytics.reports
        guard let period = try analytics.reportsPeriod(days: AnalyticsMCPContext.days(arguments)),
              reports.hasRows(.installs) || reports.hasRows(.sessions)
        else { throw MCPToolError.unavailable(analytics.noRows(.installs)) }
        func split(_ dimension: ReportDimension) -> JSONValue {
            let rows = (reports.records(.installs) + reports.records(.sessions)).within(period)
            return .array(AnalyticsMCPBreakdown.names(rows, dimension).map { name in
                let numbers = AfterDownloadNumbers.make(reports, period: period) { AnalyticsMCPBreakdown.key($0, dimension) == name }
                return ["name": .string(name), "numbers": AnalyticsMCPContext.afterDownload(numbers)]
            })
        }
        var result: [String: JSONValue] = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "reports": .array([analytics.reportStatus(.installs), analytics.reportStatus(.sessions), analytics.reportStatus(.widgets)]),
            "period": AnalyticsMCPJSON.period(period),
            "all": AnalyticsMCPContext.afterDownload(AfterDownloadNumbers.make(reports, period: period)),
            "notes": ["A sample: only people who share analytics with developers.", "Apple completes each day up to 5 days later."],
        ]
        if let breakdown {
            result["by"] = .string(breakdown.name)
            result["rows"] = split(breakdown.dimension)
        } else {
            result["byProductPage"] = split(.page)
            result["bySource"] = split(.source)
            result["byCampaign"] = split(.campaign)
            result["byAppVersion"] = split(.appVersion)
        }
        return .read(.object(result), target: "\(analytics.app.name) · After the download")
    }
}
