//
//  GetPricingStrategyTool.swift
//  Atlas
//

import Foundation

/// `get_pricing_strategy`: the app's pricing mode and strategy, the ones
/// Pricing shows and the price tools suggest from (Customize… for the app,
/// else Settings → Pricing), with the limits Customize… allows and any
/// strategy suggestion still waiting.
struct GetPricingStrategyTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_pricing_strategy",
        title: "Get the pricing strategy",
        description: """
        Reads how Atlas suggests an app's prices: its pricing mode (keepPrices: no suggestions; showSuggestions; \
        applyRecommended) and its strategy (method, base country, price index, intensity, floor, ceiling, minimum \
        proceeds, discounts only, never raise, tiers, rounding, region multipliers, countries kept at Apple's price). \
        from says whose it is: app (set in Pricing → Customize…) or settings (Settings → Pricing's defaults). \
        get_prices' suggestions and propose_prices' checks use this strategy. Also returns the limits each setting \
        takes and the strategy suggestion waiting for the person, if any. Read-only; change it with \
        propose_pricing_strategy.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let modes = context.workspace.pricingModes
        let mode = modes.mode(for: app.id)
        let strategy = modes.strategy(for: app.id)
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "mode": .string(mode.rawValue),
            "modeTitle": .string(mode.title),
            "modeChosen": .bool(modes.chosenMode(for: app.id) != nil),
            "strategy": MCPPricingStrategyJSON.json(strategy),
            "from": modes.hasOwnStrategy(app.id) ? "app" : "settings",
            "isCustom": .bool(strategy.isCustom),
            "limits": [
                "intensity": Self.range(MCPPricingStrategyJSON.intensityRange),
                "floor": Self.range(MCPPricingStrategyJSON.floorRange),
                "ceiling": Self.range(MCPPricingStrategyJSON.ceilingRange),
                "regionMultipliers": Self.range(MCPPricingStrategyJSON.regionRange),
            ],
        ]
        if let suggestion = modes.strategySuggestion(for: app.id) {
            result["suggestionWaiting"] = Self.json(suggestion)
        }
        if mode == .keepPrices {
            result["note"] = "Keep my prices shows no suggestions: the strategy only matters with showSuggestions or applyRecommended."
        }
        return .read(.object(result), target: String(localized: "\(app.name) · Pricing strategy", comment: "kind:other"))
    }

    private static func range(_ range: ClosedRange<Double>) -> JSONValue {
        .array([.double(range.lowerBound), .double(range.upperBound)])
    }

    static func json(_ suggestion: PricingStrategySuggestion) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(suggestion.id),
            "title": .string(suggestion.title),
            "why": .string(suggestion.why),
            "by": .string(suggestion.source),
        ]
        if let mode = suggestion.mode { object["mode"] = .string(mode.rawValue) }
        if let strategy = suggestion.strategy { object["strategy"] = MCPPricingStrategyJSON.json(strategy) }
        return .object(object)
    }
}
