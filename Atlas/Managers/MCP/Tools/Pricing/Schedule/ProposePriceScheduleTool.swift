//
//  ProposePriceScheduleTool.swift
//  Atlas
//

import Foundation

/// `propose_price_schedule`: when a subscription's price changes in the
/// push start, and whether existing subscribers keep their price, as the
/// schedule sheet ("Starts now" / Review & Push's Edit…) sets it. It's
/// written into every queued price change of that subscription; nothing is
/// pushed.
struct ProposePriceScheduleTool: MCPTool {
    var now: () -> Date = { .now }

    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = MCPToolDefinition.withConfidence([
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "productId": MCPToolDefinition.string("The subscription's Apple ID, product ID or name, from get_prices."),
        "startDate": MCPToolDefinition.string("The day prices change, YYYY-MM-DD, from tomorrow on; \"now\" or left out for as soon as Apple processes them."),
        "preserveCurrentPrice": [
            "type": "boolean",
            "description": "true (the default): existing subscribers keep what they pay; only new ones get the new prices.",
        ],
    ])

    let definition = MCPToolDefinition(
        name: "propose_price_schedule",
        title: "Propose when prices change",
        description: """
        Sets when a subscription's price changes waiting in Review & Push start (startDate, YYYY-MM-DD from \
        tomorrow, or "now") and whether existing subscribers keep their price (preserveCurrentPrice, default true), \
        as the schedule sheet does: it applies to every price change of that subscription in the push, the person's \
        too, and the person sees it in Review & Push before pushing. increases lists the countries whose price goes \
        up: Apple tells their subscribers, and in some countries they have to agree or the subscription ends, so \
        say so in your reason when preserveCurrentPrice is false. Refused for in-app purchases (their prices change \
        when pushed) and when no price change of the subscription waits (propose_prices first).
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "productId"]),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let product = try catalog.requireProduct(arguments.string("productId"))
        let schedule = try PriceSchedule(
            startDay: Self.startDay(arguments.optionalString("startDate"), today: now()),
            preservesCurrentPrice: arguments.optionalBool("preserveCurrentPrice") ?? true
        )
        let target = "\(catalog.app.name) · \(product.name) · Schedule"
        guard !product.isInAppPurchase else {
            return .refused(String(localized: "\(product.name) is an in-app purchase: its prices change when the person pushes, without a schedule."), target: target)
        }
        let queue = context.workspace.changes
        let prefix = PriceChangeFactory.changeID(productID: product.id, territoryID: "")
        let waiting = queue.changes(for: catalog.app.id, section: .subscriptionPricing).filter { $0.id.hasPrefix(prefix) }
        guard !waiting.isEmpty else {
            return .refused(String(localized: "No price change of \(product.name) waits in Review & Push. Propose prices with propose_prices first."), target: target)
        }
        let before = PriceSchedule.current(in: queue, appID: catalog.app.id, productID: product.id)
        if before == schedule {
            return MCPToolOutcome(
                result: ["status": "unchanged", "note": .string(String(localized: "Its price changes already follow this schedule."))],
                isError: false,
                logLines: [.init(target: target, outcome: .read)]
            )
        }
        let count = schedule.apply(in: queue, appID: catalog.app.id, productID: product.id)
        try queue.attach(arguments.layers(), to: waiting.map(\.id))
        let sheet = try await catalog.sheet(for: product)
        let consent = PriceIncreaseConsent(rows: sheet.rows(), subscribers: nil)
        var result: [String: JSONValue] = [
            "status": "queued",
            "changes": .int(count),
            "schedule": .string(schedule.note),
            "increases": .array(consent.items.map { item in
                [
                    "territory": .string(item.territory.id),
                    "from": MCPPriceValue.json(item.oldPrice),
                    "to": MCPPriceValue.json(item.newPrice),
                ]
            }),
        ]
        if let day = schedule.startDay { result["startDate"] = .string(day) }
        result["preserveCurrentPrice"] = .bool(schedule.preservesCurrentPrice)
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// "2026-12-01", nil for now; refused before tomorrow, as the sheet's
    /// date picker starts there.
    static func startDay(_ text: String?, today: Date, calendar: Calendar = .current) throws -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed.lowercased() != "now" else { return nil }
        let expected = String(localized: "a day from tomorrow on as YYYY-MM-DD, or \"now\"")
        guard let date = PriceSchedule.date(ofDay: trimmed, in: calendar), PriceSchedule.day(of: date, in: calendar) == trimmed else {
            throw MCPToolError.invalidArgument(name: "startDate", expected: expected)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        guard date >= tomorrow else { throw MCPToolError.invalidArgument(name: "startDate", expected: expected) }
        return trimmed
    }
}
