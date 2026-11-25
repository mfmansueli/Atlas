//
//  ReviewReplacementToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_review_replies` with replace: a new text for a reply already
/// on the App Store waits under that reply (Now | New) for the person to
/// send; Reply Automatically never sends it.
@MainActor
@Suite("Review reply replacements over MCP")
struct ReviewReplacementToolTests {
    typealias Data = ReviewsTestData

    private let store = ReviewsTestData.store()

    private func propose(_ reply: JSONValue) async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace()
        let tool = ProposeReviewRepliesTool(store: store)
        let arguments = MCPToolArguments(["appId": "Lumen Journal", "replies": [reply]])
        return try await tool.call(arguments, in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    private func skippedReason(_ outcome: MCPToolOutcome) -> String? {
        outcome.result["details"]?["skipped"]?.arrayValue?.first?["reason"]?.stringValue
            ?? outcome.result["skipped"]?.arrayValue?.first?["reason"]?.stringValue
    }

    @Test func aReplacementWaitsUnderThePublishedReply() async throws {
        let outcome = try await propose([
            "reviewId": "fr1", "text": "Merci ! L’export PDF arrive en 1.5.", "meaning": "Thanks! PDF export comes in 1.5.",
            "replace": true, "why": "The reply promises a fix that shipped in 1.4.",
        ])
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["replacements"] == .int(1))
        let archive = store.archive(for: Data.app.id)
        let review = try #require(archive.review(id: "fr1"))
        let replacement = try #require(archive.openReplacement(for: review))
        #expect(replacement.isReplacement)
        #expect(replacement.replaces?.text == "Merci !")
        #expect(replacement.why == "The reply promises a fix that shipped in 1.4.")
        #expect(archive.openSuggestion(for: review) == nil)
        #expect(archive.openReplacementCount == 1)
        // Nothing was sent: the published reply is unchanged.
        #expect(review.reply?.text == "Merci !")
    }

    @Test func withoutReplaceAPublishedReplyIsSkippedWithHowToReplaceIt() async throws {
        let outcome = try await propose(["reviewId": "fr1", "text": "Merci encore", "meaning": "Thanks again"])
        #expect(outcome.result["status"] == "refused")
        #expect(skippedReason(outcome)?.contains("replace: true") == true)
    }

    @Test func aReplacementNeedsWhy() async throws {
        let outcome = try await propose(["reviewId": "fr1", "text": "Merci encore", "meaning": "Thanks again", "replace": true])
        #expect(outcome.result["status"] == "refused")
        #expect(skippedReason(outcome)?.contains("why") == true)
    }

    @Test func theSameTextIsntAReplacement() async throws {
        let outcome = try await propose(["reviewId": "fr1", "text": "Merci !", "meaning": "Thanks!", "replace": true, "why": "Shorter."])
        #expect(outcome.result["status"] == "refused")
        #expect(store.archive(for: Data.app.id).openReplacementCount == 0)
    }

    @Test func replaceOnAReviewWithoutAReplyIsSkipped() async throws {
        let outcome = try await propose(["reviewId": "de1", "text": "Danke", "meaning": "Thanks", "replace": true, "why": "Test."])
        #expect(outcome.result["status"] == "refused")
        #expect(skippedReason(outcome)?.contains("no reply yet") == true)
    }

    @Test func aReplacementStopsShowingOnceTheReplyChanges() {
        let suggestion = ReviewReplySuggestion(
            reviewID: "fr1", text: "Merci, c’est corrigé.", meaning: "Thanks, it's fixed.", source: "Claude Code", date: Data.now,
            replaces: Data.reply("reply-fr", text: "Merci !"), why: "Fixed in 1.4."
        )
        let review = Data.review("fr1", "FR", rating: 4, language: "fr", version: "1.2", daysAgo: 30, reply: Data.reply("reply-fr", text: "Merci beaucoup"))
        var archive = ReviewsArchive()
        archive.reviews = [review]
        archive.suggestions["fr1"] = suggestion
        #expect(archive.openReplacement(for: review) == nil)
    }
}
