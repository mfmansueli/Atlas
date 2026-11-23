//
//  AutoReplyKeyWritingTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reply Automatically through the person's API key when Claude Code can't
/// start (board 58): only when the key may read reviews; the replies are
/// kept under their reviews and decided by the rule like any others.
@MainActor
@Suite("AutoReply key writing")
struct AutoReplyKeyWritingTests {
    private let app = ReviewsTestData.app
    private let now = ReviewsTestData.now
    private let secrets = InMemorySecretStore()
    private let answer = """
    Here you go:
    ```json
    {"replies": [
      {"reviewId": "us5", "text": "Thank you so much!", "meaning": "Thanks", "waitTopics": [], "unsure": false},
      {"reviewId": "de1", "text": "Danke, wir schauen uns den Absturz an.", "meaning": "We'll look at the crash",
       "waitTopics": ["bug", "nonsense"]},
      {"reviewId": "elsewhere", "text": "Not asked for"}
    ]}
    ```
    """

    private func center() -> AutoReplyCenter {
        let center = AutoReplyCenter()
        center.now = { now }
        center.isPro = { true }
        center.notifier = AtlasNotifier(center: nil, preferences: NotificationPreferences(defaults: nil))
        var rule = AutoReplyRule()
        rule.isOn = true
        rule.mode = .sendAllowed
        center.setRule(rule, for: app.id)
        center.update(app.id) { $0.rule.onSince = now.addingTimeInterval(-6 * 86400) }
        return center
    }

    private func store() -> ReviewsStore {
        ReviewsTestData.store(reviews: [
            ReviewsTestData.review("de1", "DE", rating: 1, language: "de", daysAgo: 1),
            ReviewsTestData.review("us5", "US", rating: 5, language: "en", daysAgo: 0.1),
        ])
    }

    /// A launcher whose helper isn't ready: Claude Code can't start.
    private func launcher() -> ClaudeCodeLauncher {
        ClaudeCodeTestFixtures.launcher(assistants: MCPTestFixtures.controller(server: FakeLocalHTTPServer()))
    }

    private func keyAssistant(readsReviews: Bool, service: StubKeyAssistantService) throws -> KeyAssistantController {
        let controller = KeyAssistantController(service: service, secrets: secrets, defaults: nil)
        let configuration = KeyAssistantConfiguration(
            vendor: .anthropic, model: AIProviderVendor.anthropic.assistantModels(available: [])[0], keySuffix: "", readsReviews: readsReviews
        )
        try controller.save(configuration, key: "sk-ant-api03-test-key-4f2Q")
        return controller
    }

    @Test func theKeyWritesWhenClaudeCodeCant() async throws {
        let center = center()
        let store = store()
        let service = StubKeyAssistantService(suggestions: answer)
        let keyAssistant = try keyAssistant(readsReviews: true, service: service)
        await center.writeReplies(app: app, reviews: store, launcher: launcher(), keyAssistant: keyAssistant)

        let request = try #require(service.completions.first)
        #expect(request.wantsJSON)
        #expect(request.system.contains(AutoReplyTone.warm.instruction))
        #expect(request.user.contains("\"reviewId\":\"us5\""))
        #expect(store.archive(for: app.id).suggestions["us5"]?.text == "Thank you so much!")
        #expect(store.archive(for: app.id).suggestions["elsewhere"] == nil)
        #expect(center.draft(for: "us5", appID: app.id)?.state.isScheduled == true)
        #expect(center.draft(for: "de1", appID: app.id)?.topics == [.bug])
        #expect(center.draft(for: "de1", appID: app.id)?.state.needsYou == true)
        #expect(center.archive(for: app.id).writeProblem == nil)
        #expect(keyAssistant.recentRequests.first?.title == "Replies to 2 reviews")
    }

    @Test func theKeyNeedsReviewsAllowed() async throws {
        let center = center()
        let service = StubKeyAssistantService(suggestions: answer)
        let keyAssistant = try keyAssistant(readsReviews: false, service: service)
        await center.writeReplies(app: app, reviews: store(), launcher: launcher(), keyAssistant: keyAssistant)
        #expect(service.completions.isEmpty, "No review goes to the vendor")
        #expect(center.archive(for: app.id).writeProblem?.contains("lets it read reviews") == true)
    }

    @Test func withoutEitherItSaysWhy() async {
        let center = center()
        await center.writeReplies(app: app, reviews: store(), launcher: launcher(), keyAssistant: nil)
        #expect(center.archive(for: app.id).writeProblem?.contains("add an API key") == true)
    }

    @Test func anUnreadableAnswerSaysSo() async throws {
        let center = center()
        let keyAssistant = try keyAssistant(readsReviews: true, service: StubKeyAssistantService(suggestions: "Sorry."))
        await center.writeReplies(app: app, reviews: store(), launcher: launcher(), keyAssistant: keyAssistant)
        #expect(center.archive(for: app.id).writeProblem?.hasPrefix("Couldn’t write a reply with your API key") == true)
        #expect(center.reviewsToWrite(for: app.id, reviews: store().archive(for: app.id)).isEmpty, "Asked again after the timeout")
    }

    @Test func theAnswerIsReadFromAFence() throws {
        let replies = try AutoReplyKeyAnswer.parse(answer, vendor: .anthropic)
        #expect(replies.map(\.reviewId) == ["us5", "de1", "elsewhere"])
        #expect(replies[1].topics == [.bug])
        #expect(throws: AIProviderError.self) { try AutoReplyKeyAnswer.parse("no JSON", vendor: .anthropic) }
    }
}
