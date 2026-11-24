//
//  ProposeNominationSubmitTool.swift
//  Atlas
//

import Foundation

/// `propose_nomination_submit`: an assistant asks the person to submit a
/// ready draft to Apple's editors. It waits on the draft; the person
/// confirms and pushes. The assistant never submits.
struct ProposeNominationSubmitTool: MCPTool {
    var store = NominationsStore.shared
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "propose_nomination_submit",
        title: "Ask to submit a nomination",
        description: """
        Asks the person to submit a draft nomination to Apple's editors, with why now. It waits on the draft in \
        Atlas's Nominations (status "queued"); the person's Accept opens the same confirmation as their own Submit…, \
        and only then is the Submit row in Review & Push. You can't submit. Refused with the reasons when the draft \
        isn't ready (fix it with propose_nomination first), its start date has passed or it was already submitted; \
        "unchanged" when its Submit row already waits. After submitting, a nomination can't be changed, only \
        archived, and Apple doesn't say whether it's featured.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPNominationAction.properties("Why submit it now, e.g. “It starts in 6 weeks; editors ask for a few.”"),
            required: ["appId", "nominationId", "why"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        try await MCPNominationAction(action: .submit, store: store, now: now).call(arguments, in: context)
    }
}
