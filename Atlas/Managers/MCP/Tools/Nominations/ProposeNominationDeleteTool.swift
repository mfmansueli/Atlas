//
//  ProposeNominationDeleteTool.swift
//  Atlas
//

import Foundation

/// `propose_nomination_delete`: an assistant asks to delete a draft
/// nomination App Store Connect has, one that isn't needed anymore. It's
/// the change the draft's Delete makes (`NominationChangeBuilder.delete`),
/// waiting in Review & Push until the person accepts it there.
struct ProposeNominationDeleteTool: MCPTool {
    var store = NominationsStore.shared
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "propose_nomination_delete",
        title: "Ask to delete a draft nomination",
        description: """
        Asks to delete a draft nomination in App Store Connect that isn't needed, e.g. a duplicate or a launch that \
        was dropped, with why. It waits in Review & Push until the person accepts it there (status "queued"), then \
        goes with their push. Refused for a nomination that was submitted (propose_nomination_archive), one that's \
        only a draft in Atlas, or one the person has changes for; "unchanged" when its delete already waits.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPNominationAction.properties("Why delete it, e.g. “The same launch has a newer draft.”"),
            required: ["appId", "nominationId", "why"]
        ),
        proposalKind: .storeText
    )

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
        if let refusal = refusal(nomination, model: model, source: context.source) { return .refused(refusal, target: target) }
        let builder = NominationChangeBuilder(appID: app.id)
        var change = builder.delete(nomination, now: now())
        if context.workspace.changes.change(id: change.id) != nil {
            return MCPToolOutcome(result: ["status": "unchanged"], isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        change.source = context.source
        change.awaitingAcceptance = String(localized: "Deletes the draft “\(nomination.displayName)” from App Store Connect. Accept it to push it.", comment: "kind:other")
        let layers = try SuggestionLayers(details: arguments.optionalString("details") ?? why, confidence: arguments.layers()?.confidence)
        context.workspace.changes.upsert(change)
        context.workspace.changes.attach(layers.nonEmpty, to: change.id)
        return MCPToolOutcome(
            result: ["status": "queued", "changeId": .string(change.id)],
            isError: false,
            logLines: [.init(target: target, outcome: .proposed)]
        )
    }

    /// Why this nomination can't be deleted by request; nil when it can.
    private func refusal(_ nomination: Nomination, model: NominationsViewModel, source: ChangeSource) -> String? {
        guard nomination.state == .draft else {
            return String(localized: "“\(nomination.displayName)” was submitted: archive it with propose_nomination_archive instead.", comment: "kind:error")
        }
        guard nomination.isInAppStoreConnect else {
            return String(localized: "“\(nomination.displayName)” is only a draft in Atlas, not in App Store Connect: the person deletes it there.", comment: "kind:error")
        }
        let deleteID = NominationChangeBuilder.changeID(.delete, nominationID: nomination.id)
        let theirs = model.queued(nomination.id).values.filter { $0.source != source && $0.id != deleteID }
        guard theirs.isEmpty else {
            return String(localized: "The person has changes for “\(nomination.displayName)” in Review & Push; only they delete it now.", comment: "kind:error")
        }
        return nil
    }
}
