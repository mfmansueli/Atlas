//
//  GetPushHistoryTool.swift
//  Atlas
//

import Foundation

/// `get_push_history`: what the person pushed for an app, newest first, as
/// Review & Push's Activity lists it: when, what each push sent and what
/// App Store Connect refused, with Apple's reason. Read-only.
struct GetPushHistoryTool: MCPTool {
    static let defaultLimit = 10
    /// Changes listed per push before `more`.
    static let changesPerPush = 40

    let definition = MCPToolDefinition(
        name: "get_push_history",
        title: "Get the push history",
        description: """
        Lists what the person pushed for an app, newest first, as Review & Push's Activity shows it: each push's date, \
        title, how many changes reached App Store Connect and how many it refused, the changes (changeId, section, \
        title, from → to, by) and each refusal with Apple's reason (failures). Use it to see when something changed \
        (a price, a text, screenshots) before reading Analytics, or why a change still waits. section keeps only that \
        section's changes; limit is \(defaultLimit) pushes unless given. Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "section": MCPToolDefinition.string("Only this section's changes, e.g. storePage or subscriptionPricing."),
                "limit": ["type": "integer", "description": .string("At most this many pushes (default \(defaultLimit)).")],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let section = try arguments.optionalString("section").map(GetQueuedChangesTool.section)
        let limit = try max(1, arguments.optionalInt("limit") ?? Self.defaultLimit)
        let records = context.workspace.pushHistory()
            .filter { $0.appID == app.id }
            .filter { record in section.map { wanted in (record.pushed + record.failedChanges).contains { $0.section == wanted } } ?? true }
            .sorted { $0.date > $1.date }
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "count": .int(records.count),
            "pushes": .array(records.prefix(limit).map { Self.json($0, section: section, source: context.source) }),
        ]
        if records.count > limit { result["more"] = .int(records.count - limit) }
        if records.isEmpty { result["note"] = "Nothing was pushed for this app from this Mac yet." }
        return .read(.object(result), target: String(localized: "\(app.name) · Push history", comment: "kind:other"))
    }

    static func json(_ record: PushRecord, section: AppWorkspaceSection?, source: ChangeSource) -> JSONValue {
        let pushed = record.pushed.filter { section == nil || $0.section == section }
        let failed = record.failedChanges.filter { section == nil || $0.section == section }
        var object: [String: JSONValue] = [
            "date": .string(record.date.formatted(.iso8601)),
            "title": .string(record.title),
            "succeeded": .int(record.succeededCount),
            "failed": .int(record.failedCount),
            "changes": .array(pushed.prefix(changesPerPush).map { MCPQueuedChangeJSON.json($0, source: source) }),
        ]
        if pushed.count > changesPerPush { object["moreChanges"] = .int(pushed.count - changesPerPush) }
        if !failed.isEmpty {
            object["failures"] = .array(failed.map { change in
                ["changeId": .string(change.id), "title": .string(change.title), "reason": .string(record.failures[change.id] ?? "")]
            })
        }
        if let screenshots = record.screenshots {
            object["screenshots"] = ["pushed": .int(screenshots.pushedCount), "failed": .int(screenshots.failedCount)]
        }
        return .object(object)
    }
}
