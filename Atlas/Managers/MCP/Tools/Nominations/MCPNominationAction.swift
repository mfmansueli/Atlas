//
//  MCPNominationAction.swift
//  Atlas
//

import Foundation

/// `propose_nomination_submit` and `propose_nomination_archive`: an
/// assistant asks the person to submit a ready draft, or archive a
/// nomination. The request waits on the nomination; its Accept opens the
/// same confirmation as the person's own Submit… or Archive…, and only
/// then is the row in Review & Push. The assistant never submits.
@MainActor
struct MCPNominationAction {
    var action: NominationActionRequest.Action
    var store: NominationsStore
    var now: () -> Date

    static func properties(_ why: String) -> [String: JSONValue] {
        MCPToolDefinition.withLayers([
            "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
            "nominationId": MCPToolDefinition.string("The nomination's id from get_nominations."),
            "why": MCPToolDefinition.why(why),
            "evidence": ["type": "array", "items": ["type": "string"], "description": "What it rests on, e.g. the start date."],
        ])
    }

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let id = try arguments.string("nominationId")
        let why = try arguments.string("why").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !why.isEmpty else { throw MCPToolError.invalidArgument(name: "why", expected: String(localized: "one sentence the person can check")) }
        var target = String(localized: "\(app.name) · Nominations · \(id)", comment: "kind:other")
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: target) }
        let model = await MCPNominations.load(app, store: store, in: context, now: now())
        guard let nomination = model.nomination(id) else {
            return .refused(String(localized: "No nomination “\(id)” includes \(app.name). Read get_nominations for the ids.", comment: "kind:error"), target: target)
        }
        target = String(localized: "\(app.name) · Nominations · \(nomination.displayName)", comment: "kind:other")
        if let problem = problem(nomination, model: model) { return problem.outcome(target: target) }
        let request = try NominationActionRequest(
            id: "nomination-request-\(UUID().uuidString.lowercased())",
            nominationID: nomination.id,
            action: action,
            evidence: AssistantEvidence(
                client: context.clientName, summary: nomination.displayName, why: why,
                evidence: arguments.optionalStrings("evidence") ?? [], layers: arguments.layers()
            ),
            receivedAt: now()
        )
        let replaced = store.add(request, for: app.id)
        let result: JSONValue = [
            "status": "queued",
            "requestId": .string(request.id),
            "replacedYourEarlierRequest": .bool(!replaced.isEmpty),
            "showsIn": .string("Nominations → “\(nomination.displayName)”, “Suggested by \(context.clientName)”"),
            "note": .string(action == .submit
                ? "The person confirms Submit to Apple’s Editors and pushes: you can't submit. After it, the nomination can't be changed, only archived."
                : "The person confirms Archive and pushes. Apple's editors stop seeing it; an archived nomination can't come back."),
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    private struct Problem {
        var status: String
        var reasons: [String]

        func outcome(target: String) -> MCPToolOutcome {
            let result: JSONValue = ["status": .string(status), "reasons": .array(reasons.map(JSONValue.string))]
            let outcome: MCPCallOutcome = status == "refused" ? .refused : .read
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: outcome, reason: reasons.joined(separator: " "))])
        }
    }

    private func problem(_ nomination: Nomination, model: NominationsViewModel) -> Problem? {
        let queued = model.queued(nomination.id)
        switch action {
        case .submit:
            guard nomination.state == .draft else {
                return Problem(status: "refused", reasons: [String(localized: "“\(nomination.displayName)” was already submitted.", comment: "kind:error")])
            }
            if queued[.submit] != nil {
                return Problem(status: "unchanged", reasons: [String(localized: "Its Submit row already waits in Review & Push.", comment: "kind:other")])
            }
            let problems = model.problems(nomination)
            if !problems.isEmpty {
                let fix = String(localized: "Fix it with propose_nomination first.", comment: "kind:error")
                return Problem(status: "refused", reasons: problems + [fix])
            }
        case .archive:
            if nomination.state == .archived {
                return Problem(status: "refused", reasons: [String(localized: "“\(nomination.displayName)” is already archived.", comment: "kind:error")])
            }
            guard nomination.state == .submitted else {
                let reason = String(
                    localized: "Only a submitted nomination is archived. A draft that isn’t needed is deleted by the person.", comment: "kind:error"
                )
                return Problem(status: "refused", reasons: [reason])
            }
            if queued[.archive] != nil {
                return Problem(status: "unchanged", reasons: [String(localized: "Its Archive row already waits in Review & Push.", comment: "kind:other")])
            }
        }
        return nil
    }
}
