//
//  WithdrawEventTextsTool.swift
//  Atlas
//

import Foundation

/// `withdraw_event_texts`: takes back an assistant's own In-App Event text
/// suggestions and revisions that still wait for the person, e.g. the stale ones
/// get_in_app_events marks (App Store Connect has that language written
/// since). Another assistant's suggestions, and texts the person accepted
/// (those wait in Review & Push), are left alone.
struct WithdrawEventTextsTool: MCPTool {
    var store = InAppEventsStore.shared

    let definition = MCPToolDefinition(
        name: "withdraw_event_texts",
        title: "Withdraw In-App Event text suggestions",
        description: """
        Withdraws your own text suggestions for an In-App Event that still wait for the person (get_in_app_events' \
        openSuggestions with your client as `by`), new texts and revisions alike (`revision: true`), e.g. the ones in \
        `staleSuggestions`, whose language App Store Connect has written since. `locales` lists the languages, or \
        "all" for every one of yours on the event. Only \
        suggestions sent by this client are removed; `withdrawn` lists them and `left` the languages that weren't, \
        with why (another assistant's, or none waiting). Texts already accepted wait in Review & Push and aren't \
        touched. Nothing reaches App Store Connect.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "locales": [
                    "type": "array", "items": ["type": "string"],
                    "description": "The languages whose suggestions to withdraw, e.g. [\"de-DE\"], or [\"all\"] for all of yours.",
                ],
            ],
            required: ["appId", "eventId", "locales"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let eventID = try arguments.string("eventId")
        guard let locales = try arguments.optionalStrings("locales"), !locales.isEmpty else {
            throw MCPToolError.invalidArgument(name: "locales", expected: String(localized: "a list of locale codes, or all"))
        }
        let open = store.open(for: app.id, eventID: eventID)
        let mine = open.filter { $0.source == context.clientName }
        let wanted = locales == ["all"] ? mine.map(\.locale) : locales
        var withdrawn: [InAppEventTextSuggestion] = []
        var left: [JSONValue] = []
        for locale in Self.unique(wanted) {
            if let suggestion = mine.first(where: { $0.locale == locale }) {
                withdrawn.append(suggestion)
            } else if let other = open.first(where: { $0.locale == locale }) {
                left.append(["locale": .string(locale), "reason": .string("Suggested by \(other.source), not by you: left for the person.")])
            } else {
                left.append(["locale": .string(locale), "reason": "No suggestion waits for this language."])
            }
        }
        if !withdrawn.isEmpty { store.remove(Set(withdrawn.map(\.id)), for: app.id) }
        let target = "\(app.name) · \(eventID) · text suggestions"
        return MCPToolOutcome(
            result: [
                "status": withdrawn.isEmpty ? "unchanged" : "withdrawn",
                "withdrawn": .array(withdrawn.map { .string($0.locale) }),
                "withdrawnRevisions": .array(withdrawn.filter(\.isRevision).map { .string($0.locale) }),
                "left": .array(left),
            ],
            isError: false,
            logLines: withdrawn.isEmpty
                ? [.init(target: target, outcome: .read)]
                : [.init(target: "\(target) · withdrew \(withdrawn.map(\.locale).joined(separator: ", "))", outcome: .proposed)]
        )
    }

    /// `codes` without repeats, in their order.
    private static func unique(_ codes: [String]) -> [String] {
        var seen: Set<String> = []
        return codes.filter { seen.insert($0).inserted }
    }
}
