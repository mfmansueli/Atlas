//
//  GetAnalyticsChangesTool.swift
//  Atlas
//

import Foundation

/// `get_analytics_changes`: what each pushed change did, as Analytics →
/// Changes shows it: the 28 days before against the 28 after (or the days
/// so far), on the funnel step the change works on and the steps after.
/// Read-only.
struct GetAnalyticsChangesTool: MCPTool {
    static let defaultLimit = 10
    var store = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "get_analytics_changes",
        title: "Get what pushed changes did",
        description: """
        Reads what the person's pushes did, as Analytics → Changes shows them, newest first: each change (search \
        text, page text, screenshots, prices, in-app texts) with its date, title, languages, from → to for a single \
        text, and its result: the \(ResultsEvaluator.windowDays) days before against the \(ResultsEvaluator.windowDays) \
        after on the step it works on (main) and the steps after (others), each rate before and after with the \
        comparison (higherSure, higherFairlySure, aboutTheSame, lowerFairlySure, lowerSure or tooFewToTell). state is final, measuring (day N of \
        \(ResultsEvaluator.windowDays), final on ends) or noBefore (Apple's data doesn't reach back). Never claim a \
        change worked while it's measuring or tooFewToTell. Prices also have Pricing → Results. limit is \
        \(defaultLimit) changes unless given. Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "limit": ["type": "integer", "description": .string("At most this many changes (default \(defaultLimit)).")],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let analytics = try await AnalyticsMCPContext.load(app: arguments.string("appId"), in: context.workspace, store: store)
        let limit = try max(1, arguments.optionalInt("limit") ?? Self.defaultLimit)
        let changes = ChangeLog.changes(for: analytics.app.id, in: context.workspace.pushHistory())
        var result: [String: JSONValue] = [
            "appId": .string(analytics.app.id),
            "app": .string(analytics.app.name),
            "count": .int(changes.count),
            "changes": .array(changes.prefix(limit).map { change in
                Self.json(change, result: ChangeResult.make(change, dataset: analytics.dataset, context: analytics.context))
            }),
            "notes": .array(analytics.notes),
        ]
        if changes.count > limit { result["more"] = .int(changes.count - limit) }
        if changes.isEmpty { result["note"] = "No pushed change Analytics measures yet: texts, screenshots and prices pushed from this Mac show here." }
        return .read(.object(result), target: String(localized: "\(analytics.app.name) · Analytics changes", comment: "kind:other"))
    }

    static func json(_ change: MeasuredChange, result: ChangeResult?) -> JSONValue {
        var object: [String: JSONValue] = [
            "kind": .string(change.kind.rawValue),
            "date": .string(change.date.formatted(.iso8601)),
            "title": .string(change.title),
            "locales": .array(change.localeCodes.map(JSONValue.string)),
        ]
        if let old = change.oldValue { object["from"] = .string(old) }
        if let new = change.newValue { object["to"] = .string(new) }
        guard let result else {
            object["result"] = .null
            return .object(object)
        }
        var measured: [String: JSONValue] = [
            "before": AnalyticsMCPJSON.period(result.before),
            "after": AnalyticsMCPJSON.period(result.after),
            "main": side(result.main),
            "others": .array(result.others.map(side)),
            "status": .string(result.statusText),
        ]
        switch result.state {
        case .final: measured["state"] = "final"
        case let .measuring(day, ends):
            measured["state"] = "measuring"
            measured["day"] = .int(day)
            measured["ends"] = .string(ends.formatted(.iso8601))
        case .noBefore: measured["state"] = "noBefore"
        }
        object["result"] = .object(measured)
        return .object(object)
    }

    private static func side(_ side: ChangeResult.Side) -> JSONValue {
        [
            "step": .string(side.title),
            "before": AnalyticsMCPJSON.rate(side.before),
            "after": AnalyticsMCPJSON.rate(side.after),
            "comparison": AnalyticsMCPJSON.comparison(side.comparison),
        ]
    }
}
