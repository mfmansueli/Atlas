//
//  MCPHandArrangementQueue.swift
//  Atlas
//

import Foundation

/// What `propose_screenshot_removal` and `propose_screenshot_order` share:
/// reading the set they're for, checking what they'd do to it as the
/// language page would (the primary language keeps one screenshot), and
/// queuing the suggestion on the Screenshots language page. Nothing in
/// the set changes until the person accepts it there.
@MainActor
enum MCPHandArrangementQueue {
    static let evidenceSchema = MCPToolDefinition.schema(
        ["kind": MCPToolDefinition.string("git, code, review, …"), "ref": MCPToolDefinition.string("What to look at.")],
        required: ["kind", "ref"]
    )

    /// The arguments both tools take besides what they name.
    static let commonProperties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "locale": MCPToolDefinition.string("The language, e.g. de-DE."),
        "displayType": MCPToolDefinition.string("iphone, iphone_duo, ipad, mac, watch or vision_pro."),
        "reason": MCPToolDefinition.shortWhy("Why, for the person to read before accepting."),
        "evidence": ["type": "array", "items": evidenceSchema],
    ]

    static func queue(
        _ action: ScreenshotHandArrangement.Action,
        _ arguments: MCPToolArguments,
        in context: MCPToolContext,
        naming: (MCPScreenshotHandSet) throws -> Result<[ScreenshotHandPlace], MCPScreenshotHandSet.Refusal>
    ) async throws -> MCPToolOutcome {
        var draft = try await MCPScreenshotsDraft.load(app: arguments.string("appId"), in: context.workspace)
        let locale = try draft.locale(arguments.string("locale"))
        let display = try MCPScreenshotHandSet.displayType(arguments.string("displayType"))
        let reason = try arguments.string("reason")
        let evidence = try Self.evidence(arguments)
        let target = "\(draft.app.name) · \(locale.code) · \(display.shortTitle)"
        let handSet = try await MCPScreenshotHandSet.load(draft, locale: locale, displayType: display, in: context.workspace)
        guard !handSet.places.isEmpty else {
            return .refused(String(localized: """
            \(locale.name) has no \(display.title) screenshots of its own (the App Store shows the primary language’s), so there’s \
            nothing to delete or move.
            """), target: target)
        }
        let places: [ScreenshotHandPlace]
        switch try naming(handSet) {
        case let .success(named): places = named
        case let .failure(refusal): return .refused(refusal.reason, target: target)
        }
        let arrangement = ScreenshotHandArrangement(
            id: ProposeTemplateTool.newID(), client: context.clientName, receivedAt: .now, locale: locale.code, displayType: display,
            action: action, places: places, reason: reason, evidence: evidence
        )
        let after: ScreenshotHandSet
        switch arrangement.applied(to: handSet.set, isPrimary: handSet.isPrimary) {
        case let .success(set): after = set
        case .failure(.lastPrimary):
            return .refused(String(localized: """
            \(locale.name) is the primary language: Apple needs at least one \(display.title) screenshot in it, so one must stay.
            """), target: target)
        case .failure(.unchanged):
            return .refused(String(localized: "That’s how the set is already: nothing would change."), target: target)
        case .failure(.changed):
            return .refused(String(localized: "Name each screenshot the set has, once."), target: target)
        }
        // A newer suggestion of the same kind for the set replaces the waiting one.
        var arrangements = (draft.document.handArrangements ?? []).filter { old in
            !(old.isWaiting && old.locale == locale.code && old.displayType == display && old.action == action)
        }
        arrangements.append(arrangement)
        draft.document.handArrangements = arrangements
        try await draft.save()
        let result: [String: JSONValue] = [
            "status": "queued",
            "proposalId": .string(arrangement.id),
            "after": .array(ScreenshotHandPlace.kept(in: after).map { .string($0.mcpID) }),
            "showsIn": .string("Screenshots → \(locale.name) → \(display.title), to accept or dismiss, then Review & Push"),
            "next": """
            The person accepts or dismisses it; pushing deletes or moves the screenshots. Never push it yourself. \
            Positions change once it's accepted: read get_screenshot_context again before naming more by position.
            """,
        ]
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// `evidence`: `[{kind, ref}]`, or none.
    private static func evidence(_ arguments: MCPToolArguments) throws -> [SuggestionEvidence] {
        try (arguments.optionalArray("evidence") ?? []).map { entry in
            guard let kind = entry["kind"]?.stringValue, let ref = entry["ref"]?.stringValue else {
                throw MCPToolError.invalidArgument(name: "evidence", expected: String(localized: "a list of {kind, ref} objects"))
            }
            return SuggestionEvidence(kind: kind, ref: ref)
        }
    }

    /// A list of whole numbers, or nil when absent.
    static func positions(_ name: String, in arguments: MCPToolArguments) throws -> [Int]? {
        guard let values = try arguments.optionalArray(name) else { return nil }
        return try values.map { value in
            guard let int = value.intValue else { throw MCPToolError.invalidArgument(name: name, expected: String(localized: "a list of positions from 1")) }
            return int
        }
    }
}
