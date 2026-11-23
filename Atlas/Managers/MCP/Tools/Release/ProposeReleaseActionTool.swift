//
//  ProposeReleaseActionTool.swift
//  Atlas
//

import Foundation

/// `propose_release_action`: an assistant proposes what to do with a
/// version on its way to the App Store (submit it with these choices,
/// release it, pause, resume or complete its phased release, cancel its
/// submission, send it back to App Review). Nothing is sent: it waits on
/// the Overview's version card with the reason until the person confirms
/// it, which runs the card's own action. Refused, with why and what's
/// possible, when the version's state doesn't allow it.
struct ProposeReleaseActionTool: MCPTool {
    var proposals = ReleaseProposalStore.shared
    var now: () -> Date = { .now }

    private static let properties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "action": [
            "type": "string",
            "enum": .array(ReleaseProposal.Action.allCases.map { .string($0.rawValue) }),
            "description": "What to do; get_release's possibleActions lists what the version allows now.",
        ],
        "platform": MCPToolDefinition.string("IOS, MAC_OS, VISION_OS or TV_OS; the version being prepared or on its way when left out."),
        "versionString": MCPToolDefinition.string("The version you mean, e.g. 1.4: refused when it isn't the one get_release shows."),
        "buildId": MCPToolDefinition.string(
            "submit: the build's id from get_release's builds; the attached one, else the newest ready, when left out."
        ),
        "buildNumber": MCPToolDefinition.string("submit: the build's number instead of buildId, e.g. 212."),
        "releaseType": [
            "type": "string", "enum": ["MANUAL", "AFTER_APPROVAL", "SCHEDULED"],
            "description": "submit: what happens on approval; the version's own when left out.",
        ],
        "releaseDate": MCPToolDefinition.string("submit with SCHEDULED: not before this ISO 8601 date and time (rounded down to the hour)."),
        "phasedRelease": ["type": "boolean", "description": "submit: release over 7 days to automatic updates (default true)."],
        "encryption": [
            "type": "string", "enum": ["exempt", "noEncryption", "other"],
            "description": "submit: the build's encryption answer, when it has none.",
        ],
        "eventIds": [
            "type": "array", "items": ["type": "string"],
            "description": "submit: the In-App Events that go to App Review with it (get_release's offeredEvents).",
        ],
        "reason": MCPToolDefinition.string("Why, in a sentence the person can check, e.g. what changed since the last release."),
        "evidence": ["type": "array", "items": ["type": "string"], "description": "e.g. CHANGELOG.md — 1.4: Mood Calendar; Crashes: 0.1% on day 3"],
    ]

    let definition = MCPToolDefinition(
        name: "propose_release_action",
        title: "Propose a release action",
        description: """
        Proposes what to do with a version on its way to the App Store, with a reason and evidence: submit (for App \
        Review, with buildId or buildNumber, releaseType MANUAL/AFTER_APPROVAL/SCHEDULED with releaseDate, \
        phasedRelease, encryption when the build has no answer, and eventIds), release (an approved version waiting \
        for the person), pause_phased_release, resume_phased_release, complete_phased_release (everyone now), \
        cancel_submission (while it waits for review) or resubmit (a rejected submission back to App Review once \
        it's fixed). Nothing is sent: it waits on the version card in Atlas (status "queued") until the person \
        confirms it; submit opens the Submit sheet with your choices for their Submit. One proposal per app and \
        platform: a new one replaces your own. "refused" says why and what's possible, e.g. a build Apple is still \
        processing, What's New missing in a language (write it with suggest_fields first), or a version already \
        with App Review. "unchanged" means the same is already waiting. Withdraw yours with \
        withdraw_release_action; get_release's proposals say what became of them.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "action", "reason"]),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let actionName = try arguments.string("action")
        guard let action = ReleaseProposal.Action(rawValue: actionName.lowercased()) else {
            let names = ReleaseProposal.Action.allCases.map(\.rawValue).formatted(.list(type: .or))
            throw MCPToolError.invalidArgument(name: "action", expected: names)
        }
        let reason = try arguments.string("reason").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            throw MCPToolError.invalidArgument(name: "reason", expected: String(localized: "why, in a sentence the person can check"))
        }
        let platform = try MCPRelease.platform(arguments)
        let release = try await MCPRelease.load(app, platform: platform, in: context)
        var target = String(localized: "\(app.name) · Release · \(action.rawValue)")
        guard let status = release.status(on: platform) else {
            return .refused(String(localized: "\(app.name) has no App Store version yet: propose one with propose_app_version."), target: target)
        }
        let version = status.version
        target = String(localized: "\(app.name) · \(action.title(version: version.versionString))")
        if let wanted = try arguments.optionalString("versionString"), wanted != version.versionString {
            let reason = String(localized: "The version on its way for \(version.platform ?? app.name) is \(version.versionString), not \(wanted). Read get_release again.")
            return .refused(reason, target: target)
        }
        if let problem = ReleaseProposalRules.problem(action, in: status) {
            return .refused(problem, target: target, details: Self.possible(status))
        }
        var notes: [String] = []
        var submission: ReleaseProposalSubmission?
        if action == .submit {
            let readiness = await MCPReleaseReadiness.load(for: status, app: app, in: context, now: now())
            let checked = try MCPReleaseSubmitProposal.make(from: arguments, status: status, readiness: readiness, now: now())
            guard checked.refusals.isEmpty, let made = checked.submission else {
                return Self.refused(checked.refusals, target: target)
            }
            submission = made
            notes = checked.notes
        }
        let proposal = try ReleaseProposal(
            id: ReleaseProposal.makeID(), appID: app.id, versionID: version.id, versionString: version.versionString, platform: version.platform,
            action: action, submission: submission,
            evidence: AssistantEvidence(
                client: context.clientName, summary: action.title(version: version.versionString), why: reason,
                evidence: arguments.optionalStrings("evidence") ?? []
            ),
            receivedAt: now()
        )
        return queue(proposal, notes: notes, target: target)
    }

    /// Keeps it, unless the same waits already or another assistant's
    /// proposal waits for that version.
    private func queue(_ proposal: ReleaseProposal, notes: [String], target: String) -> MCPToolOutcome {
        let waiting = proposals.pending(for: proposal.appID).filter { $0.platform == proposal.platform }
        if let same = waiting.first(where: { $0.client == proposal.client && $0.asks(sameAs: proposal) }) {
            let result: JSONValue = ["status": "unchanged", "proposalId": .string(same.id), "action": .string(same.action.rawValue)]
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        if let other = waiting.first(where: { $0.client != proposal.client }) {
            let reason = String(
                localized: "\(other.client)’s proposal “\(other.title)” waits for the person on the version card; they confirm or dismiss it first."
            )
            return .refused(reason, target: target)
        }
        let replaced = proposals.add(proposal)
        var result: [String: JSONValue] = [
            "status": "queued",
            "proposalId": .string(proposal.id),
            "action": .string(proposal.action.rawValue),
            "versionString": .string(proposal.versionString),
            "platform": proposal.platform.map(JSONValue.string) ?? .null,
            "note": .string(proposal.action == .submit
                ? String(localized: """
                It waits on the Overview’s version card. Confirm opens the Submit sheet with these choices; nothing goes to \
                App Review until the person presses Submit.
                """)
                : String(localized: "It waits on the Overview’s version card. Nothing is sent until the person confirms it there.")),
        ]
        if !notes.isEmpty { result["notes"] = .array(notes.map(JSONValue.string)) }
        if !replaced.isEmpty { result["replaced"] = .array(replaced.map(JSONValue.string)) }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    private static func refused(_ reasons: [String], target: String) -> MCPToolOutcome {
        let result: JSONValue = ["status": "refused", "reasons": .array(reasons.map(JSONValue.string))]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
    }

    /// `possibleActions`, for a refusal.
    private static func possible(_ status: ReleaseStatus) -> [String: JSONValue] {
        [
            "phase": .string(status.phase.key),
            "possibleActions": .array(ReleaseProposalRules.possibleActions(in: status).map { .string($0.rawValue) }),
        ]
    }
}
