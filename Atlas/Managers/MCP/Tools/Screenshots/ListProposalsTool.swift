//
//  ListProposalsTool.swift
//  Atlas
//

import Foundation

/// `list_proposals`: the app's screenshot proposals and where each stands,
/// with the Product Page Optimization tests and the release actions
/// proposed for it.
struct ListProposalsTool: MCPTool {
    var releaseProposals = ReleaseProposalStore.shared

    let definition = MCPToolDefinition(
        name: "list_proposals",
        title: "List screenshot and release proposals",
        description: """
        Lists the screenshot proposals sent for an app, oldest first: proposalId, kind (template or captions), \
        the template version a template proposal is based on, and status: pending, stale (based on an older \
        template version; the person rebases or discards it), accepted, partial or rejected. pageTests lists the \
        Product Page Optimization tests proposed with propose_page_test, when there are any. releaseProposals lists \
        the release actions proposed with propose_release_action, oldest first, when there are any: proposalId \
        (rp-…), action, title, versionString, platform, client, reason, status (pending, confirmed, dismissed, \
        withdrawn or replaced) and when it was received and settled. Withdraw your own pending one with \
        withdraw_suggestion or withdraw_release_action and its proposalId.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let release = releaseProposals.proposals(for: app.id).map { MCPReleaseJSON.json($0, problem: nil) }
        let draft: MCPScreenshotsDraft
        do {
            draft = try await MCPScreenshotsDraft.load(app: app.id, in: context.workspace)
        } catch {
            // The release proposals don't need the screenshots.
            guard !release.isEmpty else { throw error }
            let result: JSONValue = [
                "appId": .string(app.id),
                "proposals": [],
                "screenshotsError": .string(error.localizedDescription),
                "releaseProposals": .array(release),
            ]
            return .read(result, target: String(localized: "\(app.name) · Suggestions"))
        }
        var result: [String: JSONValue] = ["appId": .string(draft.app.id), "proposals": .array(Self.screenshotProposals(in: draft))]
        if let tests = draft.document.extras?.testProposals, !tests.isEmpty {
            result["pageTests"] = .array(tests.map(MCPPageTestsJSON.proposal))
        }
        if !release.isEmpty { result["releaseProposals"] = .array(release) }
        return .read(.object(result), target: draft.target)
    }

    private static func screenshotProposals(in draft: MCPScreenshotsDraft) -> [JSONValue] {
        let current = draft.document.history?.currentNumber
        return draft.document.proposals.map { proposal -> JSONValue in
            let isStale = current.map { proposal.isStale(currentVersion: $0) } ?? false
            var entry: [String: JSONValue] = [
                "proposalId": .string(proposal.id),
                "kind": .string(proposal.kind.rawValue),
                "title": .string(proposal.title),
                "client": .string(proposal.client),
                "status": .string(isStale ? "stale" : proposal.status.toolValue),
                "receivedAt": .string(proposal.receivedAt.formatted(.iso8601)),
            ]
            if let basedOn = proposal.basedOnVersion { entry["basedOn"] = .int(basedOn) }
            if proposal.kind == .captions { entry["captions"] = .int(proposal.captions.count) }
            return .object(entry)
        }
    }
}
