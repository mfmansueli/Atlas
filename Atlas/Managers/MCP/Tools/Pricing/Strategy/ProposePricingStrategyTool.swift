//
//  ProposePricingStrategyTool.swift
//  Atlas
//

import Foundation

/// `propose_pricing_strategy`: suggests a different pricing mode or
/// strategy for one app, the settings the person changes in Pricing's mode
/// menu and Customize…. It's Atlas's own setting, so it isn't a change in
/// Review & Push: it waits as a card at the top of Pricing with Now and
/// New, and changes nothing until the person accepts it (with Undo). A new
/// suggestion replaces the earlier one; `withdraw` takes it back.
struct ProposePricingStrategyTool: MCPTool {
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "propose_pricing_strategy",
        title: "Suggest a pricing strategy",
        description: """
        Suggests how Atlas should suggest an app's prices: its pricing mode (showSuggestions, applyRecommended, or \
        keepPrices for no suggestions) and its strategy, the settings of Pricing → Customize…. Read \
        get_pricing_strategy first: strategy holds only the settings that change (each in the range limits gives), \
        applied over the app's strategy as Customize… applies them (changing a setting of Suggested makes it a price \
        index); reset: true starts from Suggested. Give a title (what changes, at most 8 words, e.g. “Price Europe at \
        90%”), why with the evidence (sales, reviews, a region's conversion) and details. It waits as a card at the top \
        of Pricing until the person accepts or dismisses it; nothing is pushed, and accepting changes only Atlas's \
        suggestions, not a price. A new suggestion replaces yours; withdraw: true takes it back. Refused when nothing \
        would change, or for a strategy while the app keeps its prices (suggest mode showSuggestions with it).
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "mode": MCPToolDefinition.string("showSuggestions, applyRecommended or keepPrices; leave out to keep the app's."),
                "strategy": MCPPricingStrategyJSON.editSchema,
                "reset": ["type": "boolean", "description": "true: start from Suggested (keeping the base country) before strategy's settings."],
                "title": MCPToolDefinition.string("What changes, at most 8 words, e.g. “Price Europe at 90%”."),
                "why": MCPToolDefinition.why("Why, for the person."),
                "withdraw": ["type": "boolean", "description": "true: take back your suggestion waiting for this app; nothing else is read."],
            ]),
            required: ["appId"]
        ),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = String(localized: "\(app.name) · Pricing strategy", comment: "kind:other")
        guard context.allows(.prices) else { return .refused(MCPProposalKind.prices.refusal, target: target) }
        let modes = context.workspace.pricingModes
        if try arguments.optionalBool("withdraw") == true {
            guard let waiting = modes.strategySuggestion(for: app.id), waiting.source == context.clientName else {
                return .refused(String(localized: "No strategy suggestion of yours waits for \(app.name).", comment: "kind:error"), target: target)
            }
            modes.removeStrategySuggestion(for: app.id)
            return MCPToolOutcome(result: ["status": "withdrawn"], isError: false, logLines: [.init(target: target, outcome: .proposed)])
        }
        let title = try arguments.string("title")
        let why = try arguments.string("why")
        let currentMode = modes.mode(for: app.id)
        let current = modes.strategy(for: app.id)
        let mode = try Self.mode(arguments)
        var proposed = try arguments.optionalBool("reset") == true ? PricingStrategy.recommended(baseTerritoryID: current.baseTerritoryID) : current
        let snapshot = context.workspace.services.pricing.indexSnapshot()
        if let edits = try arguments.optionalObject("strategy") {
            proposed = try MCPPricingStrategyJSON.apply(edits, to: proposed, snapshot: snapshot)
        }
        let strategy: PricingStrategy? = proposed == current ? nil : proposed
        guard (mode.map { $0 != currentMode } ?? false) || strategy != nil else {
            return .refused(String(localized: """
            Nothing would change: \(app.name) already uses this mode and strategy. Read get_pricing_strategy and send only the settings that differ.
            """, comment: "kind:error"), target: target)
        }
        if strategy != nil, (mode ?? currentMode) == .keepPrices {
            return .refused(String(localized: """
            \(app.name) keeps its prices, so a strategy changes no suggestion. Send mode: showSuggestions with it, or only the mode.
            """, comment: "kind:error"), target: target)
        }
        let suggestion = try PricingStrategySuggestion(
            id: "ps-\(UUID().uuidString.prefix(8).lowercased())", mode: mode == currentMode ? nil : mode, strategy: strategy,
            title: title, why: why, layers: arguments.layers(), source: context.clientName, receivedAt: now()
        )
        modes.suggestStrategy(suggestion, for: app.id)
        let comparison = PricingStrategyComparison(mode: currentMode, strategy: current, suggestion: suggestion)
        return MCPToolOutcome(
            result: [
                "status": "suggested",
                "suggestionId": .string(suggestion.id),
                "changes": .array(comparison.rows.map { ["setting": .string($0.label), "now": .string($0.now), "new": .string($0.new)] }),
                "showsIn": "Pricing, at the top: the person accepts or dismisses it. Nothing is pushed.",
            ],
            isError: false,
            logLines: [.init(target: target, outcome: .proposed)]
        )
    }

    private static func mode(_ arguments: MCPToolArguments) throws -> PricingMode? {
        guard let raw = try arguments.optionalString("mode") else { return nil }
        guard let mode = PricingMode(rawValue: raw) else {
            throw MCPToolError.invalidArgument(name: "mode", expected: "showSuggestions, applyRecommended or keepPrices")
        }
        return mode
    }
}
