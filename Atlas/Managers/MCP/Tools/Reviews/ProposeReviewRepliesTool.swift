//
//  ProposeReviewRepliesTool.swift
//  Atlas
//

import Foundation

struct ProposeReviewRepliesTool: MCPTool {
    var store = ReviewsStore.shared
    var autoReply = AutoReplyCenter.shared

    let definition = MCPToolDefinition(
        name: "propose_review_replies",
        title: "Suggest replies to reviews",
        description: """
        Suggests a reply for each review, shown under it in Atlas's Reviews with Send Reply, Edit and Dismiss. \
        `replies` is a list of {reviewId, text, meaning, waitTopics?, unsure?, confidence?}: `text` in the reviewer's own \
        language (≤5,970 characters; a few sentences is right), `meaning` (or `gloss`, at most 110 characters) what it says \
        in English, for the person, and `confidence` how sure you are of the reply, 1–3. When the \
        person has Reply Automatically on, also send `waitTopics`, what the review is about from bug, billing, account, \
        featureRequest and personal (empty when none), and `unsure: true` when you aren't sure what it means: Atlas's rule \
        decides from them which replies go out by themselves and which wait. You can't turn it on, change it or send. \
        Be specific to what the review says, read \
        the project to say what is fixed or planned, and never promise what isn't there; no personal data, no asking for a \
        better rating. A review that already has a reply is skipped, unless the item has replace: true and why (what's \
        wrong with the reply on the App Store, e.g. it promises a fix that shipped): the new text then waits under that \
        reply, labelled as a replacement with Now and New, and sending it replaces Apple's response. Reply \
        Automatically never sends a replacement. Nothing is sent to the App Store: the person sends \
        each reply. A new suggestion for the same review replaces the earlier one. \
        \(StoreTextGuidelinePlace.reviewReply.summary)
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "replies": [
                    "type": "array", "description": "{reviewId, text, meaning, waitTopics?, unsure?, confidence?} objects, one per review.",
                    // Open, as before: a client may send more than these.
                    "items": [
                        "type": "object",
                        "properties": [
                            "reviewId": MCPToolDefinition.string("The review's id from get_reviews."),
                            "text": MCPToolDefinition.string("The reply, in the reviewer's own language."),
                            "meaning": MCPToolDefinition.string("What it says in English, for the person; empty when it's in English."),
                            "gloss": MCPToolDefinition.glossProperty,
                            "waitTopics": ["type": "array", "items": ["type": "string"], "description": "bug, billing, account, featureRequest, personal."],
                            "unsure": ["type": "boolean", "description": "true when you aren't sure what the review means."],
                            "confidence": MCPToolDefinition.confidenceProperty,
                            "replace": ["type": "boolean", "description": "true: a new text for the reply the review already has."],
                            "why": MCPToolDefinition.shortWhy("With replace: why the published reply should change."),
                        ],
                        "required": ["reviewId", "text"],
                    ],
                ],
            ],
            required: ["appId", "replies"]
        ),
        proposalKind: .reviewReplies,
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
        var flags: [AppReview.ID: (topics: Set<AutoReplyTopic>, isUnsure: Bool)] = [:]
        var skipped: [JSONValue] = []
        for value in try arguments.array("replies") {
            let reviewID = value["reviewId"]?.stringValue ?? ""
            let text = (value["text"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let replaces = value["replace"]?.boolValue == true
            let why = (value["why"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let reason = Self.refusal(reviewID: reviewID, text: text, replaces: replaces, why: why, in: archive) {
                skipped.append(["reviewId": .string(reviewID), "reason": .string(reason)])
                continue
            }
            let issues = StoreTextGuidelineCheck.issues(in: text, for: .reviewReply)
            guard issues.isEmpty else {
                skipped.append([
                    "reviewId": .string(reviewID), "reason": .string(issues.assistantReason + " Fix it and send that reply again."),
                    "issues": .array(issues.map(\.json)),
                ])
                continue
            }
            let item = MCPToolArguments(value.objectValue ?? [:])
            let meaning = (value["meaning"]?.stringValue ?? value["gloss"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // The gloss is `meaning`; only how sure is kept beside it.
            let layers = try SuggestionLayers(confidence: item.layers()?.confidence).nonEmpty
            let replaced = replaces ? archive.review(id: reviewID)?.reply : nil
            kept.append(ReviewReplySuggestion(
                reviewID: reviewID, text: text, meaning: meaning, source: context.clientName, date: store.now(), layers: layers,
                replaces: replaced, why: replaced == nil ? nil : why
            ))
            // Reply Automatically never replaces a published reply.
            if replaced == nil { flags[reviewID] = Self.flags(value) }
        }
        guard !kept.isEmpty else {
            return .refused("No reply could be kept.", target: target, details: ["skipped": .array(skipped)])
        }
        let added = store.add(kept, for: app.id)
        autoReply.received(added.filter { !$0.isReplacement }, flags: flags, reviews: store.archive(for: app.id), app: app)
        let replacements = added.count(where: \.isReplacement)
        return MCPToolOutcome(
            result: [
                "status": "suggested", "replies": .int(kept.count), "replacements": .int(replacements), "skipped": .array(skipped),
                "showsIn": "Reviews (⌘8), under each review (a replacement under the reply it replaces). The person sends each reply.",
            ],
            isError: false,
            logLines: [MCPToolOutcome.LogLine(target: target, outcome: .proposed)]
        )
    }

    /// What the assistant read in the review, for Reply Automatically:
    /// the topics that wait (unknown names are left out) and whether it
    /// was unsure.
    static func flags(_ value: JSONValue) -> (topics: Set<AutoReplyTopic>, isUnsure: Bool) {
        let names = value["waitTopics"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let topics = Set(names.compactMap { AutoReplyTopic(rawValue: $0) })
        return (topics, value["unsure"]?.boolValue ?? false)
    }

    /// Why a reply can't be kept, in words the assistant can act on.
    private static func refusal(reviewID: String, text: String, replaces: Bool, why: String, in archive: ReviewsArchive) -> String? {
        guard let review = archive.review(id: reviewID) else { return "No review has this id. Use the ids from get_reviews." }
        if let reply = review.reply {
            guard replaces else {
                return "This review already has a reply on the App Store. To suggest a new text for it, send replace: true with why."
            }
            if why.isEmpty { return "A replacement needs why: what's wrong with the reply on the App Store." }
            if text == reply.text { return "That's the reply it has already." }
        } else if replaces {
            return "This review has no reply yet: leave out replace."
        }
        if text.isEmpty { return "text is empty." }
        if text.count > ReviewText.replyLimit { return "text has \(text.count) characters; a reply holds \(ReviewText.replyLimit)." }
        return nil
    }
}
