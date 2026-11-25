//
//  ProposeTemplateTool+Whole.swift
//  Atlas
//

import Foundation

/// `propose_template` with restoreVersion or starter: the whole template
/// another version or a starter has, with the changes from the current
/// version, so the person reviews and accepts it like any template
/// proposal; accepting saves that template as the next version (History's
/// Restore and Starter Templates make the same one).
extension ProposeTemplateTool {
    /// The template the proposal goes to, with its title and the note
    /// for the version.
    struct WholeTemplate {
        var template: ScreenshotTemplate
        var title: String
    }

    /// The version or starter the arguments name; nil when they name
    /// neither, so the operations are read instead.
    static func wholeTemplate(_ arguments: MCPToolArguments, in draft: MCPScreenshotsDraft) throws -> WholeTemplate? {
        let restore = try arguments.optionalInt("restoreVersion")
        let starterName = try arguments.optionalString("starter")
        guard restore != nil || starterName != nil else { return nil }
        guard restore == nil || starterName == nil else {
            throw MCPToolError.invalidArgument(name: "starter", expected: String(localized: "either restoreVersion or starter, not both"))
        }
        let current = try draft.template()
        if let restore {
            guard let version = draft.document.history?.version(restore) else {
                let number = draft.document.history?.currentNumber ?? 0
                throw MCPToolError.notFound(String(localized: "There’s no template v\(restore); the current version is v\(number). Read get_template’s history."))
            }
            return WholeTemplate(template: version.template, title: String(localized: "Back to template v\(restore)", comment: "kind:other"))
        }
        guard let name = starterName, let starter = TemplateStarter(rawValue: name) else {
            let names = TemplateStarter.allCases.map(\.rawValue).joined(separator: ", ")
            throw MCPToolError.invalidArgument(name: "starter", expected: String(localized: "one of \(names)"))
        }
        let title = current.name.components(separatedBy: " · ").first ?? current.name
        let template = ScreenshotTemplate.starter(starter, id: current.id, title: title, slotCount: draft.document.slotCount)
        return WholeTemplate(template: template, title: String(localized: "Switch to the template “\(starter.title)”", comment: "kind:other"))
    }

    /// `whole` queued as one proposal, with the changes from the current
    /// version for the person to read; refused when nothing would change.
    func proposeWhole(
        _ whole: WholeTemplate, reason: String, arguments: MCPToolArguments, draft: inout MCPScreenshotsDraft, context: MCPToolContext
    ) async throws -> MCPToolOutcome {
        let target = draft.target
        let current = try draft.template()
        guard let history = draft.document.history else {
            return .refused(String(localized: "There’s no template yet.", comment: "kind:error"), target: target)
        }
        let operations = TemplateDiff.changes(from: current, to: whole.template).map { change in
            TemplateOperation(path: change.path, value: change.new ?? .null)
        }
        guard !operations.isEmpty else {
            return .refused(String(localized: "That’s the template the app has now; nothing would change.", comment: "kind:error"), target: target)
        }
        let proposal = try ScreenshotProposal.template(
            id: Self.newID(), client: context.clientName, receivedAt: .now, title: arguments.optionalString("title") ?? whole.title,
            reason: reason, proposal: TemplateProposal(basedOn: history.currentNumber, operations: operations, whole: whole.template),
            layers: arguments.layers()
        )
        draft.document.proposals.append(proposal)
        try await draft.save()
        let result: JSONValue = [
            "status": "queued",
            "proposalId": .string(proposal.id),
            "changes": .int(operations.count),
            "stress": .array(Self.stress(of: whole.template, in: draft)),
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }
}
