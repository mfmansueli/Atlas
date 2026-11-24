//
//  GetAnalyticsSubscribersTool.swift
//  Atlas
//

import Foundation

struct GetAnalyticsSubscribersTool: MCPTool {
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_subscribers",
        title: "Get subscribers by page, campaign and offer",
        description: """
        Reads Apple's App Store Subscription Event and State reports (every subscriber, not a sample) for the last 7, 28 \
        (default) or 90 days: trials, paid subscribers and trial → paid by product page, campaign and source (where each \
        subscriber downloaded the app from); each offer by name with how many paid the regular price afterwards against \
        the average of every offer (`firstRenewal` when too young to tell); subscribers Apple couldn't charge, recovered \
        and lost to billing; Billing Grace Period on or off; plan changes and cancellation reasons; and, from the newest \
        state day, how many are in a grace period or billing retry. Complements get_analytics_subscriptions (Sales and \
        Trends). Read-only: Billing Grace Period is turned on only by the person, in Atlas.
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
        let days = try AnalyticsMCPContext.days(arguments)
        guard let period = analytics.reportsPeriod(days: days), let report = LifecycleReport.make(analytics.reports, period: period) else {
            throw MCPToolError.unavailable(analytics.noRows(.subscriptionEvents))
        }
        let reports = analytics.reports
        let all = reports.subscribers(in: period) { _ in true }
        let average = all.trialToPaidFraction
        func split(_ dimension: ReportDimension) -> JSONValue {
            let events = reports.records(.subscriptionEvents).within(period)
            let names = Set(events.map { event in
                dimension == .page ? ReportsArchive.pageName(event, defaultName: ProductPageNumbers.defaultPageName) ?? "" : event[dimension]
            })
            return .array(names.filter { !$0.isEmpty }.sorted().map { name in
                let counts = reports.subscribers(in: period) { record in
                    (dimension == .page ? ReportsArchive.pageName(record, defaultName: ProductPageNumbers.defaultPageName) ?? "" : record[dimension]) == name
                }
                return ["name": .string(name), "subscribers": AnalyticsMCPContext.subscribers(counts, average: average)]
            })
        }
        let grace = analytics.dataset.gracePeriod
        let result: JSONValue = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "reports": .array([analytics.reportStatus(.subscriptionEvents), analytics.reportStatus(.subscriptionStates)]),
            "period": AnalyticsMCPJSON.period(period),
            "all": AnalyticsMCPContext.subscribers(all),
            "byProductPage": split(.page),
            "byCampaign": split(.campaign),
            "bySource": split(.source),
            "offers": .array(report.offers.map { offer in
                [
                    "name": .string(offer.name), "type": .string(offer.type), "started": .int(offer.started),
                    "paidAfterwards": .int(offer.paidAfterwards), "rate": AnalyticsMCPJSON.rate(offer.rate),
                    "firstRenewal": offer.firstRenewal.map { .string($0.iso) } ?? .null,
                ]
            }),
            "offerAverage": report.offerAverage.map { .double(($0 * 1000).rounded() / 1000) } ?? .null,
            "billing": [
                "couldNotBeCharged": .int(report.couldNotCharge), "recovered": .int(report.recovered), "lost": .int(report.lost),
                "lostPerMonth": .int(report.lostPerMonth),
                "inGracePeriodNow": AnalyticsMCPJSON.count(report.inGracePeriod), "inBillingRetryNow": AnalyticsMCPJSON.count(report.inBillingRetry),
                "billingGracePeriod": grace.map { ["on": .bool($0.isOn), "days": $0.duration.map { .int($0.days) } ?? .null] } ?? .null,
            ],
            "planChanges": .array(report.planChanges.map { ["change": .string($0.name), "count": .int($0.count)] }),
            "cancellationReasons": .array(report.cancelReasons.filter { $0.count > 0 }.map { ["reason": .string($0.name), "count": .int($0.count)] }),
        ]
        return .read(result, target: "\(analytics.app.name) · Subscribers")
    }
}
