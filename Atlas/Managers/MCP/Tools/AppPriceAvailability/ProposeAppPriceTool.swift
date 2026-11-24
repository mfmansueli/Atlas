//
//  ProposeAppPriceTool.swift
//  Atlas
//

import Foundation

/// `propose_app_price`: the app's own price in a base territory, one of
/// Apple's price points there, queued in Review & Push as the assistant's
/// "Set up the app’s price" (or "Change the app’s price"), like Add
/// Pricing… queues it. The push sends a new price schedule from today;
/// Apple equalizes every other territory.
struct ProposeAppPriceTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_app_price",
        title: "Propose the app's price",
        description: """
        Proposes what an app itself costs to download: price in the base territory's currency (0 or "free" for \
        Free), one of Apple's price points there (get_app_price_and_availability with territory lists them), and \
        territory, the base territory (the current one, else USA). Every other territory gets Apple's equalized \
        price. It's queued in Review & Push (status "queued") as a new price schedule starting when the person \
        pushes; it replaces any prices set by hand elsewhere and scheduled changes. A price that isn't a point is \
        refused with the nearest ones; "unchanged" means it's already the price. A paid price needs the Paid \
        Applications agreement, which Atlas can't check: say so in reason when the app wasn't paid before. Give \
        a reason and evidence (e.g. the project's paywall or a README).
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "price": ["type": ["number", "string"], "description": "e.g. 2.99, or 0 / \"free\"."],
                "territory": MCPToolDefinition.string("The base territory, e.g. USA or US."),
                "reason": MCPToolDefinition.why("Why this price, in a sentence the person can check."),
                "evidence": ["type": "array", "items": ["type": "string"], "description": "e.g. README.md:12 — “Free with Pro upgrade”"],
            ]),
            required: ["appId", "price"]
        ),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let sale = try await MCPAppPriceAvailability.load(app: arguments.string("appId"), in: context.workspace)
        guard let value = arguments.values["price"], let price = MCPAppPriceAvailability.price(from: value) else {
            throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "a price such as 2.99, or 0 for Free"))
        }
        let state = try await sale.price()
        let territories = try await sale.territories()
        let code = try arguments.optionalString("territory") ?? state.current?.baseTerritoryID ?? AppTerritory.unitedStates.id
        guard let territoryID = MCPAppPriceAvailability.territoryID(matching: code, among: territories.map(\.id)) else {
            throw MCPToolError.invalidArgument(name: "territory", expected: String(localized: "a territory code such as USA or US"))
        }
        let ladder = try await sale.ladder(in: territoryID)
        let territory = AppTerritory(id: territoryID, currencyCode: ladder.currencyCode)
        let target = "\(sale.app.name) · App price · \(territory.name)"
        guard let point = ladder.point(at: price) else {
            let nearest = MCPAppPriceAvailability.points(in: ladder, around: price).map { MCPPriceValue.json($0.customerPrice) }
            let reason = String(localized: "Apple has no \(AppPriceText.price(price, currencyCode: ladder.currencyCode)) price in \(territory.name).")
            return .refused(reason, target: target, details: ["nearest": .array(nearest)])
        }
        if let current = state.current, current.baseTerritoryID == territoryID, current.point?.customerPrice == point.customerPrice {
            return MCPToolOutcome(result: ["status": "unchanged"], isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        let id = AppPriceChangeBuilder.changeID(appID: sale.app.id)
        if let queued = sale.queue.change(id: id), queued.source != context.source {
            return .refused(String(localized: "\(queued.source.title) already queued a price for \(sale.app.name) in Review & Push."), target: target)
        }
        let reason = try MCPAppPriceAvailability.reason(arguments)
        let evidence = try arguments.optionalStrings("evidence") ?? []
        let layers = try arguments.layers()
        let change = AppPriceChangeBuilder(app: sale.app).change(
            point: point, in: territory, replacing: state, source: context.source, reason: reason, evidence: evidence
        )
        sale.queue.upsert(change)
        sale.queue.attach(layers, to: change.id)
        let result: JSONValue = [
            "status": "queued",
            "changeId": .string(id),
            "value": .string(change.newValue),
            "note": .string(point.customerPrice == 0
                ? String(localized: "It waits in Review & Push until the person pushes.")
                : String(localized: "It waits in Review & Push until the person pushes. A paid price needs the Paid Applications agreement.")),
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }
}
