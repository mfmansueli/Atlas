//
//  GetNominationsTool.swift
//  Atlas
//

import Foundation

/// `get_nominations`: the featuring nominations that include an app, with
/// their state, apps, dates and linked events, as Nominations shows them:
/// App Store Connect's (drafts, submitted, archived) and drafts only on
/// this Mac, and what assistants suggested that waits for the person.
struct GetNominationsTool: MCPTool {
    var store = NominationsStore.shared
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "get_nominations",
        title: "Get featuring nominations",
        description: """
        Lists the featuring nominations that include an app: what the account tells Apple's editors about a launch \
        (APP_LAUNCH), new features (APP_ENHANCEMENTS) or new content like an event (NEW_CONTENT), weeks ahead. Each \
        has its state (DRAFT, SUBMITTED, ARCHIVED; Apple reports nothing after submitting, so there's no "featured"), \
        where it is (appStoreConnect, or thisMac for a draft not pushed yet), name, type, description, dates, devices, \
        languages, territories, linked In-App Events, links (supplementalMaterialsUris), notes, apps, who created and \
        submitted it, what waits in Review & Push, what it still misses and Apple's refusal of its last push. Filter \
        with state. `suggestions` are the nominations and requests to submit or archive that wait for the person. \
        Propose one with propose_nomination, and ask to submit or archive with propose_nomination_submit and \
        propose_nomination_archive.
        """,
        inputSchema: MCPToolDefinition.schema([
            "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
            "state": ["type": "string", "enum": ["DRAFT", "SUBMITTED", "ARCHIVED"], "description": "Only nominations in this state."],
        ], required: ["appId"])
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let state = try arguments.optionalString("state").map { text in
            guard let state = NominationState(rawValue: text.uppercased()) else {
                throw MCPToolError.invalidArgument(name: "state", expected: "DRAFT, SUBMITTED or ARCHIVED")
            }
            return state
        }
        let model = await MCPNominations.load(app, store: store, in: context, now: now())
        let nominations = model.nominations.filter { state == nil || $0.state == state }
        var result: [String: JSONValue] = [
            "app": ["id": .string(app.id), "name": .string(app.name)],
            "nominations": .array(nominations.map { MCPNominations.json($0, in: model) }),
            "suggestions": .array(suggestions(model)),
            "note": """
            Nothing reaches App Store Connect until the person pushes. A draft on this Mac (where thisMac) is created \
            when its Create row is pushed; submitting is a separate row the person adds after a confirmation, and after \
            it a nomination can only be archived.
            """,
        ]
        if let problem = MCPNominations.readProblem(model) { result["readProblem"] = .string(problem) }
        return .read(.object(result), target: String(localized: "\(app.name) · Nominations", comment: "kind:other"))
    }

    private func suggestions(_ model: NominationsViewModel) -> [JSONValue] {
        let proposals: [JSONValue] = store.proposals(for: model.app.id).map { proposal in
            var object: [String: JSONValue] = [
                "id": .string(proposal.id), "kind": proposal.isNew ? "newNomination" : "changes",
                "name": .string(proposal.content.trimmedName), "suggestedBy": .string(proposal.client),
            ]
            if let id = proposal.nominationID { object["nominationId"] = .string(id) }
            return .object(object)
        }
        let requests: [JSONValue] = store.actionRequests(for: model.app.id).map { request in
            [
                "id": .string(request.id), "kind": .string(request.action.rawValue), "nominationId": .string(request.nominationID),
                "suggestedBy": .string(request.client),
            ]
        }
        return proposals + requests
    }
}
