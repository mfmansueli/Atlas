//
//  GetInAppReviewNotesTool.swift
//  Atlas
//

import Foundation

/// `get_in_app_review_notes`: each subscription's and in-app purchase's
/// Review Notes for App Review, what `propose_in_app_review_note` changes.
struct GetInAppReviewNotesTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_in_app_review_notes",
        title: "Get In-App Review Notes",
        description: """
        Reads the Review Notes of each subscription and in-app purchase (App Store Connect's Review Information › \
        Review Notes): what App Review reads about a product, e.g. what it unlocks and how to test it. One note per \
        product, not localized. Per product: `note` (App Store Connect's with anything queued on top), `live` \
        (App Store Connect's, when a queued change differs) and who queued it, `state`, and `writesTo`: "current", \
        "next review submission" (approved: it's sent with the product's next review) or "locked: with App \
        Review". `limit` is 4,000 characters. Change one with propose_in_app_review_note, e.g. in the same task that \
        changes what a purchase unlocks.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let notes = try await MCPInAppReviewNotes.load(app: arguments.string("appId"), in: context.workspace)
        return .read(notes.json(), target: String(localized: "\(notes.app.name) · Review Notes"))
    }
}
