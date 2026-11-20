//
//  WithdrawSuggestionTool.swift
//  Atlas
//

import Foundation

/// `withdraw_suggestion`: takes back an assistant's own `suggest_fields`
/// suggestions that still wait for the person, e.g. one whose reason cites
/// a date that moved. Like `withdraw_event_texts`, only the caller's are
/// removed: another assistant's or Atlas's own, and ones the person
/// already accepted or dismissed, are left with why.
struct WithdrawSuggestionTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "withdraw_suggestion",
        title: "Withdraw field suggestions",
        description: """
        Withdraws your own suggest_fields suggestions that still wait for the person, by the id suggest_fields \
        returned (sg_7) or get_store_page and get_app_information list with their source: e.g. one whose reason \
        cites a date that has moved, or a value that's no longer right. To change one instead, send its field again \
        with suggest_fields: it replaces your open one (a new value) or takes your new reason (the same value). \
        `id`, or `ids` for several. Only suggestions sent by this client are removed; `withdrawn` lists them and \
        `left` the ids that weren't, with why (another assistant's or Atlas's own, already accepted or dismissed by \
        the person, or unknown). A value the person accepted waits in Review & Push and isn't touched. Nothing \
        reaches App Store Connect.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "id": MCPToolDefinition.string("The suggestion's id, e.g. sg_7."),
                "ids": ["type": "array", "items": ["type": "string"], "description": "Several ids, instead of id."],
            ],
            required: ["appId"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        guard let store = context.workspace.suggestions else {
            throw MCPToolError.unavailable(String(localized: "Suggestions aren’t available right now. Ask the person to open Atlas."))
        }
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let ids = try Self.unique([arguments.optionalString("id")].compactMap(\.self) + (arguments.optionalStrings("ids") ?? []))
        guard !ids.isEmpty else {
            throw MCPToolError.invalidArgument(name: "id", expected: String(localized: "a suggestion id such as sg_7, or ids"))
        }
        let source = SuggestionSource.assistant(client: context.clientName)
        var mine: [FieldSuggestion] = []
        var left: [JSONValue] = []
        for id in ids {
            guard let suggestion = store.suggestion(id: id), suggestion.appID == app.id else {
                left.append(["id": .string(id), "reason": .string(String(localized: "No suggestion with this id for \(app.name)."))])
                continue
            }
            if let reason = Self.reasonToLeave(suggestion, source: source, in: store) {
                left.append(["id": .string(id), "reason": .string(reason)])
            } else {
                mine.append(suggestion)
            }
        }
        let withdrawn = store.withdraw(mine.map(\.id))
        let target = "\(app.name) · field suggestions"
        return MCPToolOutcome(
            result: [
                "status": withdrawn.isEmpty ? "unchanged" : "withdrawn",
                "withdrawn": .array(withdrawn.map { suggestion in
                    var json: [String: JSONValue] = ["id": .string(suggestion.id), "field": .string(suggestion.target.field)]
                    if case let .storePage(locale) = suggestion.target.scope { json["locale"] = .string(locale) }
                    return .object(json)
                }),
                "left": .array(left),
            ],
            isError: false,
            logLines: withdrawn.isEmpty
                ? [.init(target: target, outcome: .read)]
                : [.init(target: "\(target) · withdrew \(withdrawn.map(\.id).joined(separator: ", "))", outcome: .proposed)]
        )
    }

    /// Why a suggestion stays: someone else's, or the person decided on it.
    private static func reasonToLeave(_ suggestion: FieldSuggestion, source: SuggestionSource, in store: FieldSuggestionStore) -> String? {
        guard suggestion.source == source else {
            return String(localized: "Suggested by \(suggestion.source.title), not by you: left for the person.")
        }
        if store.isDismissed(suggestion) { return String(localized: "The person dismissed it already.") }
        guard store.isOpen(suggestion) else {
            return String(localized: "The person accepted it already: its value waits in Review & Push, and is theirs to change.")
        }
        return nil
    }

    /// `ids` without repeats, in their order, trimmed.
    private static func unique(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
