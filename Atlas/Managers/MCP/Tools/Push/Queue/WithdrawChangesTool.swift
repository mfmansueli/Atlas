//
//  WithdrawChangesTool.swift
//  Atlas
//

import Foundation

/// `withdraw_changes`: takes the caller's own proposals back out of Review
/// & Push, by the changeId a propose_ tool or get_queued_changes gave, as
/// the person's Discard takes them out (with what depends on them). A
/// version the assistant left beside the person's goes and the person's
/// stays. The person's changes, another assistant's and Atlas's own are
/// left, with why.
struct WithdrawChangesTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "withdraw_changes",
        title: "Withdraw your queued changes",
        description: """
        Takes your own proposals back out of Review & Push by changeId (from a propose_ tool or \
        get_queued_changes), or every one of yours in a section with all: true and section. Works for any section \
        (texts, prices, offers, retention, events, product pages…). What depends on a change goes with it, as \
        Discard does; your version beside the person's leaves and theirs stays. withdrawn lists what left and \
        left the ids that stayed, with why (the person's, another assistant's, unknown). Nothing reaches App Store \
        Connect. One country's price: propose_prices with withdraw: true.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "changeId": MCPToolDefinition.string("The change's id, e.g. price.6450100002.BRA."),
                "changeIds": ["type": "array", "items": ["type": "string"], "description": "Several ids, instead of changeId."],
                "all": ["type": "boolean", "description": "true withdraws every change of yours for the app (in section, when given)."],
                "section": MCPToolDefinition.string("With all: only this section, e.g. subscriptionPricing."),
            ],
            required: ["appId"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let queue = context.workspace.changes
        let source = context.source
        let wantsAll = try arguments.optionalBool("all") == true
        let ids = try Self.ids(arguments, wantsAll: wantsAll, app: app, queue: queue, source: source)
        guard !ids.isEmpty else {
            if wantsAll {
                return MCPToolOutcome(result: ["withdrawn": [], "left": []], isError: false, logLines: [.init(target: Self.target(app), outcome: .read)])
            }
            throw MCPToolError.invalidArgument(name: "changeId", expected: String(localized: "a change id from a propose_ tool, changeIds, or all: true"))
        }
        var withdrawn: [JSONValue] = []
        var left: [JSONValue] = []
        var touchedRows: Set<String> = []
        for id in ids {
            guard let change = queue.change(id: id), change.appID == app.id else {
                left.append(["changeId": .string(id), "why": .string(String(localized: "No change with this id waits for \(app.name)."))])
                continue
            }
            guard let entry = Self.withdraw(change, in: queue, source: source) else {
                left.append(["changeId": .string(id), "why": .string(Self.whyLeft(change))])
                continue
            }
            withdrawn.append(entry)
            if let creationID = change.creation?.id, PricesByCountryChanges.isFromPricesByCountry(change) { touchedRows.insert(creationID) }
        }
        for creationID in touchedRows {
            PricesByCountryChanges.refreshSummary(in: queue, appID: app.id, creationID: creationID)
        }
        let result: JSONValue = ["withdrawn": .array(withdrawn), "left": .array(left)]
        let outcome: MCPCallOutcome = withdrawn.isEmpty ? .read : .proposed
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: Self.target(app), outcome: outcome)])
    }

    /// The ids the call names, once each: changeId, changeIds and, with
    /// all, every change of the caller's (in section, when given).
    private static func ids(
        _ arguments: MCPToolArguments,
        wantsAll: Bool,
        app: StoreApp,
        queue: ChangeQueue,
        source: ChangeSource
    ) throws -> [PendingChange.ID] {
        let section = try arguments.optionalString("section").map(GetQueuedChangesTool.section)
        var ids = try [arguments.optionalString("changeId")].compactMap(\.self) + (arguments.optionalStrings("changeIds") ?? [])
        if wantsAll {
            ids += queue.changes(for: app.id)
                .filter { section == nil || $0.section == section }
                .filter { $0.source == source || $0.alternative?.source == source }
                .map(\.id)
        }
        return ids.reduce(into: []) { list, id in if !list.contains(id) { list.append(id) } }
    }

    /// Takes the caller's change (with its dependents) or its version
    /// beside the person's out; nil when neither is the caller's.
    private static func withdraw(_ change: PendingChange, in queue: ChangeQueue, source: ChangeSource) -> JSONValue? {
        if change.source == source {
            let dependents = queue.dependents(of: [change.id])
            queue.discard(id: change.id)
            var entry: [String: JSONValue] = ["changeId": .string(change.id), "title": .string(change.title)]
            if !dependents.isEmpty { entry["withDependents"] = .array(dependents.sorted().map(JSONValue.string)) }
            return .object(entry)
        }
        guard change.alternative?.source == source else { return nil }
        queue.resolveAlternative(id: change.id, keepAlternative: false)
        return ["changeId": .string(change.id), "title": .string(change.title), "alternative": true]
    }

    /// Why a change stays: someone else's.
    static func whyLeft(_ change: PendingChange) -> String {
        if change.source.isAssistant {
            return String(localized: "\(change.source.title) proposed it, not you; it stays.")
        }
        return String(localized: "\(change.source.title) queued it; only the person takes it out.")
    }

    private static func target(_ app: StoreApp) -> String {
        String(localized: "\(app.name) · Review & Push")
    }
}
