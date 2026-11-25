//
//  ProposeAccessibilityDraftDeletionTool.swift
//  Atlas
//

import Foundation

/// `propose_accessibility_draft_deletion`: an assistant asks to delete a
/// device's accessibility draft in App Store Connect, as the card's Delete
/// Draft does (`AppInformationChangeBuilder.deleteDraftChange`). It waits
/// in Review & Push until the person accepts it there.
struct ProposeAccessibilityDraftDeletionTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_accessibility_draft_deletion",
        title: "Ask to delete an accessibility draft",
        description: """
        Asks to delete one device's accessibility draft in App Store Connect (get_app_information's accessibility \
        devices with hasDraft), e.g. one with answers the app doesn't support, as the card's Delete Draft does. \
        A published declaration isn't deleted, only replaced: suggest its answers with suggest_fields. It waits in \
        Review & Push until the person accepts it there (status "queued"); "unchanged" when it already waits. \
        Refused while the person has a change for that device.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "device": MCPToolDefinition.string("iphone, ipad, watch, vision, mac or tv."),
                "reason": MCPToolDefinition.why("Why delete the draft, for the person."),
            ]),
            required: ["appId", "device", "reason"]
        ),
        proposalKind: .appInformation
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let draft = try await MCPAppInformationDraft.load(app: arguments.string("appId"), in: context.workspace)
        let app = draft.app
        let deviceName = try arguments.string("device")
        guard let family = DeviceFamily(mcpName: deviceName) else {
            throw MCPToolError.invalidArgument(name: "device", expected: "iphone, ipad, watch, vision, mac or tv")
        }
        let target = String(localized: "\(app.name) · Accessibility · \(family.name)")
        guard context.allows(.appInformation) else { return .refused(MCPProposalKind.appInformation.refusal, target: target) }
        let reason = try arguments.string("reason")
        if let problem = AssistantTextLimits.whyRefusal(reason, field: "reason") { return .refused(problem, target: target) }
        guard draft.slots.accessibility != nil, let card = draft.slots.card(for: family) else {
            return .refused(String(localized: "Atlas couldn’t read \(app.name)’s accessibility for \(family.name). Read get_app_information again."), target: target)
        }
        if card.isDeletionQueued {
            return MCPToolOutcome(result: ["status": "unchanged"], isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        guard card.draftID != nil else {
            return .refused(String(localized: """
            \(family.name) has no accessibility draft. A published declaration is only replaced: suggest its answers with suggest_fields.
            """), target: target)
        }
        let id = draft.builder.accessibilityChangeID(family)
        if let theirs = context.workspace.changes.change(id: id), theirs.source != context.source {
            return .refused(String(localized: "The person has a change for \(family.name) in Review & Push; only they delete the draft now."), target: target)
        }
        guard var change = draft.builder.deleteDraftChange(for: card, source: context.source) else {
            return .refused(String(localized: "\(family.name) has no accessibility draft."), target: target)
        }
        change.awaitingAcceptance = String(localized: "Deletes the \(family.name) accessibility draft. Accept it to push it.")
        let layers = try SuggestionLayers(details: arguments.optionalString("details") ?? reason, confidence: arguments.layers()?.confidence)
        context.workspace.changes.upsert(change)
        context.workspace.changes.attach(layers.nonEmpty, to: change.id)
        return MCPToolOutcome(
            result: ["status": "queued", "changeId": .string(change.id)], isError: false, logLines: [.init(target: target, outcome: .proposed)]
        )
    }
}
