//
//  ReviewsToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_reviews`, `propose_review_replies` and `propose_review_themes`:
/// what an assistant reads, and what it may leave for the person to send.
@MainActor
@Suite("Reviews MCP tools")
struct ReviewsToolsTests {
    typealias Data = ReviewsTestData

    private let store = ReviewsTestData.store()

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace()
        workspace.services.reviews = FakeReviewsServices()
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    @Test func theToolsAreInTheToolboxAndSuggestingRepliesIsPro() {
        let names: Set = ["get_reviews", "propose_review_replies", "propose_review_themes"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        #expect(ProAssistantGate.refusal(forTool: "get_reviews", isPro: false) == nil)
        for tool in ["propose_review_replies", "propose_review_themes"] {
            let refusal = ProAssistantGate.refusal(forTool: tool, isPro: false)
            #expect(refusal?.hasPrefix("Suggesting replies to reviews is part of Atlas Pro") == true)
            #expect(ProAssistantGate.refusal(forTool: tool, isPro: true) == nil)
        }
        #expect(MCPEndpoint.instructions.contains("propose_review_replies"))
        #expect(GetReviewsTool().definition.isReadOnly)
        #expect(!ProposeReviewRepliesTool().definition.isReadOnly)
    }

    @Test func reviewsThatNeedAReplyAreReadNewestFirst() async throws {
        store.add([Data.suggestion("de1")], for: Data.app.id)
        let outcome = try await call(GetReviewsTool(store: store), ["appId": "Lumen Journal"])
        let result = outcome.result
        #expect(result["currentVersion"] == "1.3")
        #expect(result["counts"]?["read"] == .int(6))
        #expect(result["counts"]?["needReply"] == .int(4))
        #expect(result["counts"]?["repliesSuggested"] == .int(1))
        let reviews = try #require(result["reviews"]?.arrayValue)
        #expect(reviews.compactMap { $0["id"]?.stringValue } == ["de1", "de2", "jp1", "us1"])
        #expect(reviews[0]["language"] == "de")
        #expect(reviews[0]["territory"] == "DE")
        #expect(reviews[0]["rating"] == .int(1))
        #expect(reviews[0]["suggestedReply"]?["text"] == "Danke!")
        #expect(reviews[1]["suggestedReply"] == nil)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.read)
    }

    @Test func showAndLimitPickWhatIsRead() async throws {
        let replied = try await call(GetReviewsTool(store: store), ["appId": "Lumen Journal", "show": "replied"]).result
        let reviews = try #require(replied["reviews"]?.arrayValue)
        #expect(reviews.count == 1)
        #expect(reviews[0]["reply"]?["text"] == "Merci !")

        let limited = try await call(GetReviewsTool(store: store), ["appId": "Lumen Journal", "show": "all", "limit": 2]).result
        #expect(limited["reviews"]?.arrayValue?.count == 2)
        #expect(limited["notes"]?.arrayValue?.first?.stringValue == "4 more match; raise limit to read them.")
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetReviewsTool(store: store), ["appId": "Lumen Journal", "show": "angry"])
        }
    }

    @Test func staleReviewsAreReadFromAppStoreConnectFirst() async throws {
        let empty = ReviewsStore()
        let result = try await call(GetReviewsTool(store: empty), ["appId": "Lumen Journal", "show": "all"]).result
        #expect(result["reviews"]?.arrayValue?.count == 6)
        #expect(empty.archive(for: Data.app.id).fetchedAt != nil)
    }

    @Test func repliesBecomeSuggestionsThePersonSends() async throws {
        let outcome = try await call(ProposeReviewRepliesTool(store: store), [
            "appId": "Lumen Journal",
            "replies": [
                ["reviewId": "de1", "text": " Danke, 1.4 repariert das. ", "meaning": "Thanks, 1.4 fixes it."],
                ["reviewId": "fr1", "text": "Merci encore", "meaning": "Thanks again"],
                ["reviewId": "nobody", "text": "Hi", "meaning": "Hi"],
                ["reviewId": "jp1", "text": "", "meaning": ""],
            ],
        ])
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["replies"] == .int(1))
        let skipped = try #require(outcome.result["skipped"]?.arrayValue)
        #expect(skipped.compactMap { $0["reviewId"]?.stringValue } == ["fr1", "nobody", "jp1"])
        #expect(skipped[0]["reason"] == "This review already has a reply on the App Store.")
        let suggestion = try #require(store.archive(for: Data.app.id).suggestions["de1"])
        #expect(suggestion.text == "Danke, 1.4 repariert das.")
        #expect(suggestion.meaning == "Thanks, 1.4 fixes it.")
        #expect(suggestion.source == "Claude Code")
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)
        // Nothing was sent: the review still has no reply.
        #expect(store.archive(for: Data.app.id).review(id: "de1")?.reply == nil)
    }

    @Test func aReplyOverApplesLimitIsRefused() async throws {
        let long = String(repeating: "a", count: ReviewText.replyLimit + 1)
        let outcome = try await call(ProposeReviewRepliesTool(store: store), [
            "appId": "Lumen Journal", "replies": [["reviewId": "de1", "text": .string(long), "meaning": "a"]],
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(store.archive(for: Data.app.id).suggestions.isEmpty)
    }

    /// 5.6.1: no marketing in a reply. "Feel free" and a free trial in a
    /// support answer are fine.
    @Test func aReplyWithAPromoCodeIsSkipped() async throws {
        let outcome = try await call(ProposeReviewRepliesTool(store: store), [
            "appId": "Lumen Journal",
            "replies": [
                ["reviewId": "de1", "text": "Danke! Mit dem Rabattcode LUMEN gibt es 50 % Rabatt.", "meaning": "Thanks! Code LUMEN gives 50% off."],
                ["reviewId": "jp1", "text": "Feel free to write to us; the free trial lasts 7 days.", "meaning": "Write to us."],
            ],
        ])
        #expect(outcome.result["replies"] == .int(1))
        let skipped = try #require(outcome.result["skipped"]?.arrayValue?.first)
        #expect(skipped["reviewId"] == "de1")
        #expect(skipped["reason"]?.stringValue?.hasPrefix("Replies to reviews can’t include marketing (Guideline 5.6.1)") == true)
        #expect(store.archive(for: Data.app.id).suggestions["de1"] == nil)
        #expect(store.archive(for: Data.app.id).suggestions["jp1"] != nil)
    }

    @Test func groupsReplaceTheOnesSentBefore() async throws {
        store.add([Data.sync], for: Data.app.id)
        let outcome = try await call(ProposeReviewThemesTool(store: store), [
            "appId": "Lumen Journal",
            "themes": [
                [
                    "title": "The price feels high", "note": "They think there’s only a yearly plan.", "reviewIds": ["jp1", "nobody"],
                    "action": "open_pricing", "territory": "jp",
                ],
                [
                    "title": "iCloud sync since 1.3", "note": "Fixed in 1.4.", "reviewIds": ["de1", "de2", "us1"], "action": "reply_to_all",
                    "replies": [["language": "de", "text": "Danke."], ["language": "en", "text": "Thanks."]],
                ],
            ],
        ])
        #expect(outcome.result["status"] == "set")
        let themes = store.archive(for: Data.app.id).themes
        // Most mentioned first, and the earlier "sync" group is gone.
        #expect(themes.map(\.id) == ["icloud-sync-since-1-3", "the-price-feels-high"])
        #expect(themes[0].replies.map(\.languageCode) == ["de", "en"])
        #expect(themes[0].source == "Claude Code")
        #expect(themes[1].action == .openPricing(territory: "JP"))
        #expect(themes[1].reviewIDs == ["jp1"])
    }

    @Test func aGroupThatCantBeShownIsRefusedWithTheReason() async throws {
        let noReplies = try await call(ProposeReviewThemesTool(store: store), [
            "appId": "Lumen Journal",
            "themes": [["title": "Sync", "note": "", "reviewIds": ["de1"], "action": "reply_to_all"]],
        ])
        #expect(noReplies.result["status"] == "refused")
        let unknown = try await call(ProposeReviewThemesTool(store: store), [
            "appId": "Lumen Journal",
            "themes": [["title": "Sync", "note": "", "reviewIds": ["x"], "action": "show_reviews"]],
        ])
        #expect(unknown.result["status"] == "refused")
        let badAction = try await call(ProposeReviewThemesTool(store: store), [
            "appId": "Lumen Journal",
            "themes": [["title": "Sync", "note": "", "reviewIds": ["de1"], "action": "delete_reviews"]],
        ])
        #expect(badAction.result["status"] == "refused")
        #expect(store.archive(for: Data.app.id).themes.isEmpty)
    }

    @Test func aTitleBecomesAStableID() {
        #expect(ProposeReviewThemesTool.slug("iCloud sync since 1.3", fallback: 0) == "icloud-sync-since-1-3")
        #expect(ProposeReviewThemesTool.slug("Preço — é caro?", fallback: 0) == "preco-e-caro")
        #expect(ProposeReviewThemesTool.slug("…", fallback: 2) == "group-3")
    }
}
