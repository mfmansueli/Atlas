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
        the whole app and by product page, source, campaign and app version. Rates matter more than counts here. Read-only.
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
        let reports = analytics.reports
        guard let period = try analytics.reportsPeriod(days: AnalyticsMCPContext.days(arguments)),
              reports.hasRows(.installs) || reports.hasRows(.sessions)
        else { throw MCPToolError.unavailable(analytics.noRows(.installs)) }
        func split(_ dimension: ReportDimension) -> JSONValue {
            let rows = (reports.records(.installs) + reports.records(.sessions)).within(period)
            let key: (ReportRecord) -> String = { record in
                dimension == .page ? ReportsArchive.pageName(record, defaultName: ProductPageNumbers.defaultPageName) ?? "" : record[dimension]
            }
            return .array(Set(rows.map(key)).filter { !$0.isEmpty }.sorted().map { name in
                ["name": .string(name), "numbers": AnalyticsMCPContext.afterDownload(AfterDownloadNumbers.make(reports, period: period) { key($0) == name })]
            })
        }
        let result: JSONValue = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "reports": .array([analytics.reportStatus(.installs), analytics.reportStatus(.sessions), analytics.reportStatus(.widgets)]),
            "period": AnalyticsMCPJSON.period(period),
            "all": AnalyticsMCPContext.afterDownload(AfterDownloadNumbers.make(reports, period: period)),
            "byProductPage": split(.page),
            "bySource": split(.source),
            "byCampaign": split(.campaign),
            "byAppVersion": split(.appVersion),
            "notes": ["A sample: only people who share analytics with developers.", "Apple completes each day up to 5 days later."],
        ]
        return .read(result, target: "\(analytics.app.name) · After the download")
    }
}
