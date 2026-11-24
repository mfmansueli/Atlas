//
//  ProposeNominationArchiveTool.swift
//  Atlas
//

import Foundation

/// `propose_nomination_archive`: an assistant asks the person to archive a
/// nomination that's over or no longer true. It waits on the nomination;
/// the person confirms and pushes.
struct ProposeNominationArchiveTool: MCPTool {
    var store = NominationsStore.shared
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "propose_nomination_archive",
        title: "Ask to archive a nomination",
        description: """
        Asks the person to archive a submitted nomination, e.g. a launch that \
        moved or content that's over, with why. It waits on the nomination in Atlas's Nominations (status "queued"); \
        the person's Accept opens the same confirmation as their own Archive…, and the row is in Review & Push only \
        then. Refused when it's a draft (the person deletes those) or already archived; "unchanged" when its Archive row \
        already waits.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPNominationAction.properties("Why archive it, e.g. “The launch moved to March.”"),
            required: ["appId", "nominationId", "why"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        try await MCPNominationAction(action: .archive, store: store, now: now).call(arguments, in: context)
    }
}
