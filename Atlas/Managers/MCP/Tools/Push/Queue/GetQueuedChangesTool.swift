//
//  GetQueuedChangesTool.swift
//  Atlas
//

import Foundation

/// `get_queued_changes`: what waits in Review & Push for an app, across
/// every section, as the review sheet lists it, with the push running now.
/// Read-only: only the person pushes, discards or picks.
struct GetQueuedChangesTool: MCPTool {
    /// Changes one call lists.
    static let defaultLimit = 100

    let definition = MCPToolDefinition(
        name: "get_queued_changes",
        title: "Get what waits in Review & Push",
        description: """
        Lists what waits in Review & Push for an app, oldest first, across every section: changeId, section, \
        group, title, from → to, by (who proposed it) and mine (yours), status (ready, blocked with reason, \
        needsDecision when App Store Connect changed or two versions wait, awaitingAcceptance) and the alternative \
        version beside the person's. Filter with section (storePage, screenshots, productPages, inAppEvents, \
        nominations, appInformation, subscriptionPricing, reviews, analytics) or mine: true. push says what a push \
        running now does with each change. Take your own back with withdraw_changes; only the person pushes.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "section": MCPToolDefinition.string("Only this section's changes, e.g. subscriptionPricing."),
                "mine": ["type": "boolean", "description": "true lists only changes (or alternatives) you proposed."],
                "limit": ["type": "integer", "description": .string("At most this many changes (default \(defaultLimit)).")],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let section = try arguments.optionalString("section").map(Self.section)
        let mine = try arguments.optionalBool("mine") ?? false
        let limit = try max(1, arguments.optionalInt("limit") ?? Self.defaultLimit)
        let source = context.source
        let changes = context.workspace.changes.changes(for: app.id)
            .filter { section == nil || $0.section == section }
            .filter { !mine || $0.source == source || $0.alternative?.source == source }
            .sorted { $0.createdAt < $1.createdAt }
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "count": .int(changes.count),
            "ready": .int(changes.count { !$0.isBlocked }),
            "changes": .array(changes.prefix(limit).map { MCPQueuedChangeJSON.json($0, source: source) }),
        ]
        if changes.count > limit { result["more"] = .int(changes.count - limit) }
        if let push = context.workspace.push(), push.isRunning || !push.items.isEmpty {
            let items = push.items.filter { $0.appID == app.id }
            result["push"] = ["running": .bool(push.isRunning), "changes": .array(items.map(\.json))]
        }
        return .read(.object(result), target: String(localized: "\(app.name) · Review & Push"))
    }

    /// A section by its name (storePage) or title (Store Page).
    static func section(_ text: String) throws -> AppWorkspaceSection {
        let squeezed = { (name: String) in name.lowercased().filter { !$0.isWhitespace } }
        let key = squeezed(text)
        if let section = AppWorkspaceSection.allCases.first(where: { squeezed($0.rawValue) == key || squeezed($0.title) == key }) {
            return section
        }
        let names = AppWorkspaceSection.allCases.map(\.rawValue).joined(separator: ", ")
        throw MCPToolError.invalidArgument(name: "section", expected: String(localized: "one of \(names)"))
    }
}
