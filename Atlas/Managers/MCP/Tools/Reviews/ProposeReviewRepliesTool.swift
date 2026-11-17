//
//  ProposeReviewRepliesTool.swift
//  Atlas
//

import Foundation

struct ProposeReviewRepliesTool: MCPTool {
    var store = ReviewsStore.shared

    let definition = MCPToolDefinition(
        name: "propose_review_replies",
        title: "Suggest replies to reviews",
        description: """
        Suggests a reply for each review, shown under it in Atlas's Reviews with Send Reply, Edit and Dismiss. \
        `replies` is a list of {reviewId, text, meaning}: `text` in the reviewer's own language (≤5,970 characters; a few \
        sentences is right), `meaning` what it says in English, for the person. Be specific to what the review says, read \
        the project to say what is fixed or planned, and never promise what isn't there; no personal data, no asking for a \
        better rating. Reviews that already have a reply are skipped. Nothing is sent to the App Store: the person sends \
        each reply. A new suggestion for the same review replaces the earlier one.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "replies": [
                    "type": "array", "description": "{reviewId, text, meaning} objects, one per review.",
                    "items": ["type": "object"],
                ],
            ],
            required: ["appId", "replies"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = "\(app.name) · Review replies"
        let archive = store.archive(for: app.id)
        guard !archive.reviews.isEmpty else {
            return .refused("Atlas has no reviews of \(app.name) yet. Call get_reviews first.", target: target)
        }
        var kept: [ReviewReplySuggestion] = []
        var skipped: [JSONValue] = []
        for value in try arguments.array("replies") {
            let reviewID = value["reviewId"]?.stringValue ?? ""
            let text = (value["text"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let reason = Self.refusal(reviewID: reviewID, text: text, in: archive) {
                skipped.append(["reviewId": .string(reviewID), "reason": .string(reason)])
                continue
            }
            let meaning = (value["meaning"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            kept.append(ReviewReplySuggestion(reviewID: reviewID, text: text, meaning: meaning, source: context.clientName, date: store.now()))
        }
        guard !kept.isEmpty else {
            return .refused("No reply could be kept.", target: target, details: ["skipped": .array(skipped)])
        }
        store.add(kept, for: app.id)
        return MCPToolOutcome(
            result: [
                "status": "suggested", "replies": .int(kept.count), "skipped": .array(skipped),
                "showsIn": "Reviews (⌘7), under each review. The person sends each reply.",
            ],
            isError: false,
            logLines: [MCPToolOutcome.LogLine(target: target, outcome: .proposed)]
        )
    }

    /// Why a reply can't be kept, in words the assistant can act on.
    private static func refusal(reviewID: String, text: String, in archive: ReviewsArchive) -> String? {
        guard let review = archive.review(id: reviewID) else { return "No review has this id. Use the ids from get_reviews." }
        if review.hasReply { return "This review already has a reply on the App Store." }
        if text.isEmpty { return "text is empty." }
        if text.count > ReviewText.replyLimit { return "text has \(text.count) characters; a reply holds \(ReviewText.replyLimit)." }
        return nil
    }
}
