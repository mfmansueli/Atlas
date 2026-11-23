//
//  ProposeEventTextsTool.swift
//  Atlas
//

import Foundation

/// `propose_event_texts`: an assistant's texts for an editable event's
/// languages that aren't written yet, or with `revise` its revision of
/// texts a language already has, kept as suggestions in In-App Events
/// until the person accepts, edits or dismisses them. Each is checked
/// like an edit: Apple's limits and In-App Events guidance (2.3.13).
struct ProposeEventTextsTool: MCPTool {
    var store = InAppEventsStore.shared

    static let whyLimit = AssistantTextLimits.why

    let definition = MCPToolDefinition(
        name: "propose_event_texts",
        title: "Suggest an In-App Event's texts",
        description: """
        Suggests an In-App Event's texts in more languages, shown in Atlas's In-App Events with Accept, Dismiss and \
        Accept All Languages. `texts` is a list of {locale, name (≤30 characters), shortDescription (≤50), longDescription \
        (≤120), why, details, confidence, gloss}: all three written in that language, natural rather than literal (a \
        winter event isn't one where December is summer), in the voice of that language's store page. `why` is one \
        sentence for the person on why it reads this way (at most \(AssistantTextLimits.why) characters; the rest goes in \
        `details`, at most \(AssistantTextLimits.details)), `confidence` how sure you are (1–3) and `gloss` what the name \
        means in English (at most \(AssistantTextLimits.gloss)). Over a limit, that language is refused with its count: \
        shorten it and send it again. A \
        language get_in_app_events lists in `queuedTexts` already has texts waiting in Review & Push and is refused: \
        leave it. Only \
        events that get_in_app_events marks editable take texts. Sending a language again replaces its waiting \
        suggestion. get_in_app_events' `openSuggestions` shows what waits and who sent it, `stale` once App Store \
        Connect has that language written; take your own back with withdraw_event_texts. To change a language that's \
        already written (an editable event's: draft, ready for review or rejected), e.g. a description that names a \
        day the event no longer ends on, send revise: true (for the call, or on a text object) with only the texts to \
        change and why, required: the others stay as they are, the same rules and limits apply, and `revised` gives \
        each change against the current text (`marked`: [-removed-]{+added+}). The person sees Now and Suggested with \
        the changed words marked, and accepts, edits or dismisses it. Accepted texts wait in Review \
        & Push; nothing reaches App Store Connect until the person pushes. \(StoreTextGuidelinePlace.eventText.summary)
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "texts": [
                    "type": "array",
                    "description": """
                    {locale, name, shortDescription, longDescription, why} objects, one per language; with revise, only the \
                    texts to change, and why.
                    """,
                    "items": [
                        "type": "object",
                        "properties": .object(MCPToolDefinition.withLayers([
                            "locale": MCPToolDefinition.string("An App Store locale code, e.g. pt-BR."),
                            "name": MCPToolDefinition.string("At most 30 characters."),
                            "shortDescription": MCPToolDefinition.string("At most 50 characters."),
                            "longDescription": MCPToolDefinition.string("At most 120 characters."),
                            "why": MCPToolDefinition.why("Why it reads this way."),
                            "revise": ["type": "boolean", "description": "Revise this language's written texts."],
                        ], gloss: true)),
                    ],
                ],
                "revise": [
                    "type": "boolean",
                    "description": "Revise languages that are already written (or set revise on each text object).",
                ],
            ],
            required: ["appId", "eventId", "texts"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let eventID = try arguments.string("eventId")
        let events = try await context.workspace.services.inAppEvents.events(for: app)
        guard let event = events.first(where: { $0.id == eventID }) else {
            throw MCPToolError.notFound(String(localized: "\(app.name) has no In-App Event “\(eventID)”. Use the ids from get_in_app_events."))
        }
        let target = "\(app.name) · \(event.referenceName)"
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: target) }
        guard event.state.isEditable else {
            return .refused("“\(event.referenceName)” is \(event.state.rawValue): its texts can’t be changed any more.", target: target)
        }
        let builder = InAppEventChangeBuilder(appID: app.id)
        let queuedChanges = context.workspace.changes.changes(for: app.id, section: .inAppEvents)
        let queued = builder.queuedTexts(for: event.id, in: queuedChanges).filter { $0.completes(event.localization($0.locale)) }
        let queuedLocales = Set(queued.map(\.locale))
        var kept: [InAppEventTextSuggestion] = []
        var skipped: [JSONValue] = []
        var revised: [JSONValue] = []
        let revisesAll = try arguments.optionalBool("revise") ?? false
        let drafts = builder.drafts(for: event.id, in: queuedChanges)
        for value in try arguments.array("texts") {
            let locale = value["locale"]?.stringValue ?? ""
            if revisesAll || value["revise"]?.boolValue == true {
                let revision = try Self.revision(value, locale: locale, of: event, queued: drafts[locale] ?? [:], source: context.clientName)
                if let suggestion = revision.suggestion {
                    kept.append(suggestion)
                    revised.append(revision.json)
                } else {
                    skipped.append(revision.json)
                }
                continue
            }
            let suggestion = try InAppEventTextSuggestion(
                eventID: event.id, locale: locale, name: Self.trimmed(value["name"]), shortDescription: Self.trimmed(value["shortDescription"]),
                longDescription: Self.trimmed(value["longDescription"]), why: String(Self.trimmed(value["why"]).prefix(Self.whyLimit)),
                source: context.clientName, date: .now, layers: MCPToolArguments(value.objectValue ?? [:]).layers()
            )
            let issues = Self.guidelineIssues(suggestion)
            if let reason = Self.refusal(suggestion, event: event, queuedLocales: queuedLocales) {
                skipped.append(["locale": .string(locale), "reason": .string(reason)])
            } else if !issues.isEmpty {
                skipped.append([
                    "locale": .string(locale), "reason": .string(issues.assistantReason + " Fix it and send that language again."),
                    "issues": .array(issues.map(\.json)),
                ])
            } else {
                kept.append(suggestion)
            }
        }
        guard !kept.isEmpty else {
            return .refused("No language could be kept.", target: target, details: ["skipped": .array(skipped)])
        }
        store.add(kept, for: app.id)
        var result: [String: JSONValue] = [
            "status": "suggested", "languages": .array(kept.map { .string($0.locale) }), "skipped": .array(skipped),
            "showsIn": .string("In-App Events (⌘5) → \(event.referenceName)"),
        ]
        if !revised.isEmpty {
            result["revised"] = .array(revised)
            result["revisedNote"] = """
            Each revision shows on the event's page as Now and Suggested with the changed words marked ([-removed-] \
            {+added+} here), until the person accepts or dismisses it; the texts you left out stay as they are. \
            Withdraw your own with withdraw_event_texts.
            """
        }
        return MCPToolOutcome(
            result: .object(result),
            isError: false,
            logLines: [MCPToolOutcome.LogLine(target: target, outcome: .proposed)]
        )
    }

    static func trimmed(_ value: JSONValue?) -> String {
        (value?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What App Review would reject in a language's three texts (Apple's
    /// In-App Events guidance, 2.3.13).
    static func guidelineIssues(_ suggestion: InAppEventTextSuggestion) -> [StoreTextGuidelineIssue] {
        StoreTextGuidelineCheck.issues(in: suggestion.fields.map(suggestion.text).joined(separator: "\n"), for: .eventText)
    }

    /// Why a language can't be kept, in words the assistant can act on.
    private static func refusal(_ suggestion: InAppEventTextSuggestion, event: InAppEvent, queuedLocales: Set<String>) -> String? {
        guard StoreLocaleCatalog.locale(code: suggestion.locale) != nil else { return "“\(suggestion.locale)” isn’t an App Store locale code." }
        if event.localization(suggestion.locale)?.isComplete == true {
            return """
            This language is already written. To change some of its texts, send them with revise: true and why (only \
            the texts you send change).
            """
        }
        if queuedLocales.contains(suggestion.locale) {
            return "This language's texts are already waiting in Review & Push (queuedTexts in get_in_app_events); leave it."
        }
        if let empty = InAppEventField.allCases.first(where: { suggestion.text($0).isEmpty }) { return "\(empty.rawValue) is empty: send all three." }
        if let over = suggestion.overLimit { return "\(over.field.rawValue) has \(over.count) characters; it holds \(over.field.limit)." }
        return nil
    }
}
