//
//  ProposeInAppReviewNoteTool.swift
//  Atlas
//

import Foundation

/// `propose_in_app_review_note`: an assistant's Review Notes for a
/// subscription or in-app purchase, checked and queued in Review & Push.
struct ProposeInAppReviewNoteTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_in_app_review_note",
        title: "Propose In-App Review Note",
        description: """
        Proposes a subscription's or in-app purchase's Review Notes (App Store Connect's Review Information › Review \
        Notes), from get_in_app_review_notes: for App Review only, one per product, not localized. Update it in the \
        same task that changes what a purchase unlocks (e.g. new MCP tools a purchase opens), so review reads \
        what's true. The store text rules don't apply: the notes may mention a $0 trial or Guideline 3.1.1. Send \
        productId and note (and a reason with evidence), or several with notes: [{productId, note, reason, \
        evidence}]. Refused (status "refused", with code and reason): over 4,000 characters (over_limit), empty \
        (empty), a product the app hasn't (unknown_product), notes the person changed and hasn't pushed \
        (changed_by_person), or a product with App Review (locked). Accepted notes are queued in Review & Push \
        as the assistant's (status "queued", with writesTo: "next review submission" for an approved product); \
        nothing reaches App Store Connect until the person pushes.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "productId": MCPToolDefinition.string("The product ID, e.g. com.SimProps.complete (or its column, com.SimProps.complete.reviewNote)."),
                "note": MCPToolDefinition.string("The whole Review Notes, within 4,000 characters."),
                "reason": MCPToolDefinition.shortWhy("One sentence: why it changes."),
                "evidence": ["type": "array", "items": evidenceSchema],
                "notes": [
                    "type": "array",
                    "description": "Several at once, instead of productId and note.",
                    "items": MCPToolDefinition.schema(
                        [
                            "productId": MCPToolDefinition.string("The product ID."),
                            "note": MCPToolDefinition.string("The whole Review Notes."),
                            "reason": MCPToolDefinition.shortWhy("Why it changes."),
                            "evidence": ["type": "array", "items": evidenceSchema],
                        ],
                        required: ["productId", "note"]
                    ),
                ],
            ],
            required: ["appId"]
        ),
        proposalKind: .storeText
    )

    private static let evidenceSchema = MCPToolDefinition.schema(
        ["kind": MCPToolDefinition.string("git, code, release, …"), "ref": MCPToolDefinition.string("What to look at.")],
        required: ["kind", "ref"]
    )

    /// One product's proposed notes.
    private struct Proposal {
        var productID: String
        var note: String
        var reason: String?

        init(_ arguments: MCPToolArguments) throws {
            productID = try arguments.string("productId")
            // An empty note is refused as "empty", not as a bad call.
            guard arguments.values["note"]?.stringValue != nil else {
                throw MCPToolError.invalidArgument(name: "note", expected: String(localized: "a string"))
            }
            note = try arguments.optionalString("note") ?? ""
            let evidence = try (arguments.optionalArray("evidence") ?? []).map { entry in
                if let text = entry.stringValue { return text }
                guard let kind = entry["kind"]?.stringValue, let ref = entry["ref"]?.stringValue else {
                    throw MCPToolError.invalidArgument(name: "evidence", expected: String(localized: "a list of {kind, ref} objects"))
                }
                return "\(kind): \(ref)"
            }
            let parts = try [arguments.optionalString("reason"), evidence.isEmpty ? nil : evidence.joined(separator: "; ")]
            let reason = parts.compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " · ")
            self.reason = reason.isEmpty ? nil : reason
        }
    }

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let batch = try arguments.optionalArray("notes")
        let proposals = try batch.map { items in
            try items.map { item in
                guard let object = item.objectValue else {
                    throw MCPToolError.invalidArgument(name: "notes", expected: String(localized: "a list of {productId, note} objects"))
                }
                return try Proposal(MCPToolArguments(object))
            }
        } ?? [Proposal(arguments)]

        let queue = context.workspace.changes
        var results: [JSONValue] = []
        var logLines: [MCPToolOutcome.LogLine] = []
        for proposal in proposals {
            // Reloaded each time, so a batch's second note for a product
            // sees the first.
            let notes = try await MCPInAppReviewNotes.load(app: arguments.string("appId"), in: context.workspace)
            let target = notes.target(proposal.productID)
            var result: [String: JSONValue] = ["productId": .string(proposal.productID)]
            switch notes.propose(proposal.note, productID: proposal.productID, source: context.source, reason: proposal.reason) {
            case let .queued(change):
                queue.upsert(change)
                result["status"] = "queued"
                result["changeId"] = .string(change.id)
                let productID = notes.builder.productID(of: change) ?? proposal.productID
                result["writesTo"] = .string(MCPInAppReviewNotes.writesTo(notes.content.productStates[productID]))
                logLines.append(.init(target: target, outcome: .proposed))
            case .unchanged:
                result["status"] = "unchanged"
                result["note"] = "Those are already the notes, in App Store Connect or queued; nothing new was queued."
                logLines.append(.init(target: target, outcome: .read))
            case let .backToLive(id):
                queue.discard(id: id)
                result["status"] = "unchanged"
                result["note"] = "Those are App Store Connect's notes, so the queued change was withdrawn."
                logLines.append(.init(target: target, outcome: .read))
            case let .refused(code, reason):
                result["status"] = "refused"
                result["code"] = .string(code)
                result["reason"] = .string(reason)
                logLines.append(.init(target: target, outcome: .refused, reason: reason))
            }
            results.append(.object(result))
        }
        guard batch != nil else { return MCPToolOutcome(result: results[0], isError: false, logLines: logLines) }
        let queued = results.count { $0["status"] == "queued" }
        let refused = results.count { $0["status"] == "refused" }
        return MCPToolOutcome(result: ["results": .array(results), "queued": .int(queued), "refused": .int(refused)], isError: false, logLines: logLines)
    }
}
