//
//  ReportReviewScreenshotRunTool.swift
//  Atlas
//

import Foundation

/// `report_review_screenshot_run`: where a Make Review Screenshots… run is
/// (README — Pricing: review screenshots), so Pricing's cards and the
/// toolbar show it: each step while it works, the product it captures now,
/// and why it stopped when it couldn't find the paywall or the paywall
/// showed no prices. The images themselves come with
/// `propose_purchase_review_screenshot`.
struct ReportReviewScreenshotRunTool: MCPTool {
    var runs = ReviewShotsRunCenter.shared

    let definition = MCPToolDefinition(
        name: "report_review_screenshot_run",
        title: "Report a review screenshot run",
        description: """
        While you make App Review screenshots of an app's subscriptions and in-app purchases (Make Review \
        Screenshots… in Atlas), report where you are so the person sees it: status "working" with a short step \
        ("Opened Lumen in Simulator · iPhone 17 Pro", "Opened the paywall from Settings → Lumen Plus", "Selecting \
        Annual and waiting for its price") and productId while you capture that product; "paywall_not_found" with \
        tried (every way you tried, in one sentence) when nothing leads to a purchase screen; "no_prices" with saw \
        (what the paywall showed) when StoreKit returned no products; "done" when every product was sent with \
        propose_purchase_review_screenshot. A stop needs the person: they say where the paywall is, or let you add a \
        StoreKit configuration, and Atlas asks again.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "status": [
                    "type": "string", "enum": ["working", "paywall_not_found", "no_prices", "done"],
                    "description": "Where the run is.",
                ],
                "step": MCPToolDefinition.string("While working: what you do now, in a few words."),
                "productId": MCPToolDefinition.string("While working: the product you capture now."),
                "tried": MCPToolDefinition.string("With paywall_not_found: every way you tried."),
                "saw": MCPToolDefinition.string("With no_prices: what the paywall showed."),
            ],
            required: ["appId", "status"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let status = try arguments.string("status")
        let target = "\(app.name) · review screenshots"
        if runs.run(for: app.id) == nil {
            // Asked outside Atlas's button: show it all the same.
            runs.start(appID: app.id, client: context.clientName, products: [])
        }
        switch status {
        case "working":
            try runs.report(appID: app.id, productID: arguments.optionalString("productId"), step: arguments.optionalString("step"))
        case "paywall_not_found":
            try runs.fail(appID: app.id, .paywallNotFound(tried: arguments.optionalString("tried") ?? ""))
        case "no_prices":
            try runs.fail(appID: app.id, .noPrices(saw: arguments.optionalString("saw") ?? ""))
        case "done":
            runs.runEnded(appID: app.id)
        default:
            throw MCPToolError.invalidArgument(name: "status", expected: "working, paywall_not_found, no_prices or done")
        }
        let result: JSONValue = ["status": "saved"]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }
}
