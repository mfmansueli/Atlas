//
//  WithdrawReleaseActionTool.swift
//  Atlas
//

import Foundation

/// `withdraw_release_action`: takes back an assistant's own release
/// proposal still waiting on the version card, e.g. once a crash rate it
/// cited went back down. Like `withdraw_suggestion`, another assistant's
/// and ones the person already confirmed or dismissed are left, with why.
struct WithdrawReleaseActionTool: MCPTool {
    var proposals = ReleaseProposalStore.shared

    let definition = MCPToolDefinition(
        name: "withdraw_release_action",
        title: "Withdraw a release proposal",
        description: """
        Withdraws your own propose_release_action proposal that still waits for the person on the version card, by \
        proposalId (rp-…, from propose_release_action or get_release's proposals); every one of yours for the app \
        when left out. To change it instead, propose again: a new one replaces yours. `withdrawn` lists what was \
        taken back and `left` what wasn't, with why (another assistant's, already confirmed or dismissed, unknown).
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "proposalId": MCPToolDefinition.string("e.g. rp-3f9a1c2e."),
            ],
            required: ["appId"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let mine = proposals.pending(for: app.id).filter { $0.client == context.clientName }
        var withdrawn: [ReleaseProposal] = []
        var left: [JSONValue] = []
        if let id = try arguments.optionalString("proposalId")?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if let proposal = mine.first(where: { $0.id == id }) {
                withdrawn.append(proposal)
            } else {
                let reason = Self.reasonToLeave(proposals.proposal(id: id), appID: app.id, client: context.clientName)
                left.append(["proposalId": .string(id), "reason": .string(reason)])
            }
        } else {
            withdrawn = mine
        }
        for proposal in withdrawn {
            proposals.resolve(proposal.id, as: .withdrawn)
        }
        let target = String(localized: "\(app.name) · Release suggestions")
        return MCPToolOutcome(
            result: [
                "status": withdrawn.isEmpty ? "unchanged" : "withdrawn",
                "withdrawn": .array(withdrawn.map { ["proposalId": .string($0.id), "action": .string($0.action.rawValue)] }),
                "left": .array(left),
            ],
            isError: false,
            logLines: withdrawn.isEmpty
                ? [.init(target: target, outcome: .read)]
                : [.init(target: "\(target) · withdrew \(withdrawn.map(\.id).joined(separator: ", "))", outcome: .proposed)]
        )
    }

    /// Why a release proposal stays: unknown, another assistant's, or settled.
    static func reasonToLeave(_ proposal: ReleaseProposal?, appID: StoreApp.ID, client: String) -> String {
        guard let proposal, proposal.appID == appID else { return String(localized: "No release proposal with this id for this app.") }
        guard proposal.client == client else { return String(localized: "Proposed by \(proposal.client), not by you: left for the person.") }
        switch proposal.status {
        case .confirmed: return String(localized: "The person confirmed it already.")
        case .dismissed: return String(localized: "The person dismissed it already.")
        case .withdrawn, .replaced, .pending: return String(localized: "It doesn’t wait anymore.")
        }
    }
}
