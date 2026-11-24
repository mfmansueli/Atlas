//
//  ProposeReviewThemesTool.swift
//  Atlas
//

import Foundation

struct ProposeReviewThemesTool: MCPTool {
    var store = ReviewsStore.shared

    static let titleLimit = 60
    static let noteLimit = 240
    static let maximumThemes = 8

    let definition = MCPToolDefinition(
        name: "propose_review_themes",
        title: "Group reviews by subject",
        description: """
        Sets "What people write about" in Atlas's Reviews: up to 8 groups of reviews on one subject, most mentioned \
        first. `themes` is a list of {title (≤60 characters, e.g. "iCloud sync since 1.3"), note (≤240: what's going on and \
        what to do about it), reviewIds (from get_reviews), action, territory?, replies?}. `action` is one of reply_to_all \
        (it's fixed or answered: give `replies`, one {language, text} per language of the group's reviews, each a message \
        that fits every review of the group in that language), open_pricing (a price or plan complaint; `territory` \
        alpha-2 opens that country), suggest_store_page (the store page should say it) or show_reviews (just list them). \
        Send every group in one call: it replaces the groups sent before. Nothing is sent to the App Store; with Reply to \
        All the person reviews each language's message and sends it.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "themes": [
                    "type": "array", "description": "{title, note, reviewIds, action, territory, replies} objects.",
                    "items": ["type": "object"],
                ],
            ],
            required: ["appId", "themes"]
        ),
        proposalKind: .reviewReplies,
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = "\(app.name) · Review groups"
        let archive = store.archive(for: app.id)
        guard !archive.reviews.isEmpty else {
            return .refused("Atlas has no reviews of \(app.name) yet. Call get_reviews first.", target: target)
        }
        let values = try arguments.array("themes")
        guard values.count <= Self.maximumThemes else {
            return .refused("\(values.count) groups; send the \(Self.maximumThemes) most mentioned.", target: target)
        }
        var themes: [ReviewTheme] = []
        for (index, value) in values.enumerated() {
            switch Self.theme(value, index: index, archive: archive, source: context.clientName) {
            case let .success(theme): themes.append(theme)
            case let .failure(refusal): return .refused("Group \(index + 1): \(refusal.reason)", target: target)
            }
        }
        guard !themes.isEmpty else { return .refused("themes is empty.", target: target) }
        store.setThemes(themes.sorted { $0.reviewIDs.count > $1.reviewIDs.count }, for: app.id)
        return MCPToolOutcome(
            result: [
                "status": "set", "groups": .array(themes.map(ReviewsMCPJSON.theme)),
                "showsIn": "Reviews (⌘8) → What people write about",
            ],
            isError: false,
            logLines: [MCPToolOutcome.LogLine(target: target, outcome: .proposed)]
        )
    }

    /// Why a group can't be kept.
    struct Refusal: Error {
        var reason: String
    }

    private static func theme(_ value: JSONValue, index: Int, archive: ReviewsArchive, source: String) -> Result<ReviewTheme, Refusal> {
        let title = (value["title"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let note = (value["note"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= titleLimit else {
            return .failure(Refusal(reason: "title has \(title.count) characters; it needs 1 to \(titleLimit)."))
        }
        guard note.count <= noteLimit else { return .failure(Refusal(reason: "note has \(note.count) characters; it holds \(noteLimit).")) }
        let known = Set(archive.reviews.map(\.id))
        let reviewIDs = (value["reviewIds"]?.arrayValue ?? []).compactMap(\.stringValue).filter(known.contains)
        guard !reviewIDs.isEmpty else {
            return .failure(Refusal(reason: "none of its reviewIds is a review from get_reviews."))
        }
        guard let action = ReviewThemeAction(code: value["action"]?.stringValue ?? "", territory: value["territory"]?.stringValue) else {
            return .failure(Refusal(reason: "action must be \(ReviewThemeAction.codes.formatted(.list(type: .or)))."))
        }
        var replies: [ReviewThemeReply] = []
        for reply in value["replies"]?.arrayValue ?? [] {
            let language = (reply["language"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let text = (reply["text"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !language.isEmpty, !text.isEmpty else { return .failure(Refusal(reason: "each reply needs language and text.")) }
            guard text.count <= ReviewText.replyLimit else {
                return .failure(Refusal(reason: "the \(language) reply has \(text.count) characters; a reply holds \(ReviewText.replyLimit)."))
            }
            replies.append(ReviewThemeReply(languageCode: language, text: text))
        }
        if action == .replyToAll, replies.isEmpty {
            return .failure(Refusal(reason: "reply_to_all needs replies: one {language, text} per language of its reviews."))
        }
        let id = value["id"]?.stringValue ?? slug(title, fallback: index)
        return .success(ReviewTheme(id: id, title: title, note: note, reviewIDs: reviewIDs, action: action, replies: replies, source: source))
    }

    /// "icloud-sync-since-1-3".
    static func slug(_ title: String, fallback index: Int) -> String {
        let folded = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        let words = folded.split { !$0.isLetter && !$0.isNumber }
        return words.isEmpty ? "group-\(index + 1)" : words.joined(separator: "-")
    }
}
