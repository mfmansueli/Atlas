//
//  ProposeNominationTool.swift
//  Atlas
//

import Foundation

/// `propose_nomination`: an assistant's new featuring nomination, or
/// changes to a draft. Checked like the person's own (a type, name,
/// description and start date that hasn't passed; links only in
/// Materials), it waits in Nominations as "Suggested by <client>" until the
/// person accepts it; then it's a draft and its Create or Update row is in
/// Review & Push. Nothing is submitted: that's always the person's step.
struct ProposeNominationTool: MCPTool {
    var store = NominationsStore.shared
    var now: () -> Date = { .now }

    private static let properties: [String: JSONValue] = MCPToolDefinition.withLayers([
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "nominationId": MCPToolDefinition.string("A draft's id from get_nominations, to change it; left out for a new nomination."),
        "name": MCPToolDefinition.string("What the editors read first, e.g. Lumen 2.0: Mood Calendar."),
        "type": [
            "type": "string", "enum": ["APP_LAUNCH", "APP_ENHANCEMENTS", "NEW_CONTENT"],
            "description": "APP_LAUNCH for a new app, APP_ENHANCEMENTS for new features, NEW_CONTENT for an event or season.",
        ],
        "description": MCPToolDefinition.string("What's new, who it's for and why now, in plain sentences. No links: Apple refuses them here."),
        "publishStartDate": MCPToolDefinition.string("The first day it's on the App Store, e.g. 2027-02-02: not passed. Apple suggests weeks ahead."),
        "publishEndDate": MCPToolDefinition.string("Optional: the last day, after the start; an empty string clears it."),
        "deviceFamilies": [
            "type": "array", "items": ["type": "string", "enum": .array(NominationDevice.allCases.map { .string($0.rawValue) })],
            "description": "Where people can use it.",
        ],
        "locales": ["type": "array", "items": ["type": "string"], "description": "App Store Connect locale codes, e.g. en-US."],
        "territories": [
            "type": "array", "items": ["type": "string"],
            "description": "Optional territory codes (USA, BRA…); every country or region when left out or empty.",
        ],
        "launchInSelectMarketsFirst": ["type": "boolean", "description": "It starts in a few countries before the rest."],
        "preOrderEnabled": ["type": "boolean", "description": "People can order it before the start date."],
        "inAppEventIds": ["type": "array", "items": ["type": "string"], "description": "Linked In-App Events' ids, from get_in_app_events."],
        "supplementalMaterialsUris": [
            "type": "array", "items": ["type": "string"],
            "description": "Links to a video, deck or mockups (https://…): Apple takes links, not files.",
        ],
        "notes": MCPToolDefinition.string("Optional notes for the editorial team."),
        "otherAppIds": [
            "type": "array", "items": ["type": "string"],
            "description": "Other apps of the account it covers (ids from list_apps); the app itself is always in.",
        ],
        "why": MCPToolDefinition.why("Why nominate this now, e.g. how far ahead it starts."),
        "evidence": ["type": "array", "items": ["type": "string"], "description": "Where it comes from, e.g. CHANGELOG.md — 2.0: Mood Calendar."],
    ])

    let definition = MCPToolDefinition(
        name: "propose_nomination",
        title: "Propose a featuring nomination",
        description: """
        Proposes a featuring nomination for an app (what Apple's editors read about a launch, new features or new \
        content, weeks ahead), or changes to a draft with nominationId (only what you send changes). A new one needs \
        name, type, description and publishStartDate. It waits in Atlas's Nominations as a suggestion from you (status \
        "queued"); once the person accepts it, it's a draft and its row is in Review & Push. You can't submit: ask \
        with propose_nomination_submit, and the person confirms and pushes. Anything Apple would refuse is refused \
        with the reasons (status "refused"): a missing field, a start date that has passed, a link in the \
        description (links go in supplementalMaterialsUris), unknown events, apps, locales or territories, or a \
        nomination that isn't a draft. Never promise featuring: Apple doesn't say which nominations it picks.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "why"]),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let why = try arguments.string("why").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !why.isEmpty else { throw MCPToolError.invalidArgument(name: "why", expected: String(localized: "one sentence the person can check")) }
        let nominationID = try arguments.optionalString("nominationId")
        var target = String(localized: "\(app.name) · Nominations · new", comment: "kind:other")
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: target) }
        let model = await MCPNominations.load(app, store: store, in: context, now: now())
        var base = NominationContent(appIDs: [app.id])
        if let nominationID {
            guard let draft = model.nomination(nominationID) else {
                return .refused(String(localized: "No nomination “\(nominationID)” includes \(app.name). Read get_nominations for the ids.", comment: "kind:error"), target: target)
            }
            target = String(localized: "\(app.name) · Nominations · \(draft.displayName)", comment: "kind:other")
            guard draft.isEditable else {
                return .refused(String(localized: "“\(draft.displayName)” was submitted: it can’t be changed, only archived.", comment: "kind:error"), target: target)
            }
            base = draft.content
        }
        let parsed = try Self.content(from: arguments, over: base, model: model)
        if nominationID == nil { target = String(localized: "\(app.name) · Nominations · \(parsed.content.trimmedName)", comment: "kind:other") }
        let reasons = parsed.content.problems(now: now()) + parsed.problems
        guard reasons.isEmpty else {
            let result: JSONValue = ["status": "refused", "reasons": .array(reasons.map(JSONValue.string))]
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
        }
        if nominationID != nil, parsed.content == base {
            return MCPToolOutcome(result: ["status": "unchanged"], isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        let proposal = try NominationProposal(
            id: "nomination-proposal-\(UUID().uuidString.lowercased())",
            nominationID: nominationID,
            content: parsed.content,
            evidence: AssistantEvidence(
                client: context.clientName, summary: parsed.content.trimmedName, why: why,
                evidence: arguments.optionalStrings("evidence") ?? [], layers: arguments.layers()
            ),
            receivedAt: now()
        )
        let replaced = store.add(proposal, for: app.id)
        let days = parsed.content.daysUntilStart(now: now()) ?? 0
        var result: [String: JSONValue] = [
            "status": "queued",
            "proposalId": .string(proposal.id),
            "replacedYourEarlierSuggestion": .bool(!replaced.isEmpty),
            "showsIn": .string(nominationID == nil
                ? "Nominations → top of Drafts, “Suggested by \(context.clientName)”"
                : "Nominations → the draft's page, “Suggested by \(context.clientName)”"),
            "note": """
            It waits for the person: once they accept it, it's a draft with its row in Review & Push, and nothing reaches \
            App Store Connect until they push. Submitting is theirs: ask with propose_nomination_submit.
            """,
        ]
        if days < NominationNeed.closeDays {
            result["warning"] = .string(String(localized: "It starts in \(days) days: Apple suggests nominating a few weeks ahead. It can still be submitted.", comment: "kind:other"))
        }
        if nominationID != nil { result["changes"] = .array(parsed.content.changedFields(from: base).map { .string($0.rawValue) }) }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }
}
