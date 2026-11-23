//
//  AutoReplyCenterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reply Automatically's queue (board 58): what arrives is decided by the
/// rule, due replies go out through Send Reply's write (not before one was
/// sent by hand, never past the day's cap), and Undo takes one back.
@MainActor
@Suite("AutoReplyCenter")
struct AutoReplyCenterTests {
    private let app = ReviewsTestData.app
    private let now = ReviewsTestData.now

    private func center(rule: AutoReplyRule? = nil, isPro: Bool = true) -> (AutoReplyCenter, AtlasNotifier) {
        let center = AutoReplyCenter()
        center.now = { now }
        center.isPro = { isPro }
        let notifier = AtlasNotifier(center: nil, preferences: NotificationPreferences(defaults: nil))
        center.notifier = notifier
        var turnedOn = rule ?? AutoReplyRule()
        turnedOn.isOn = true
        if rule == nil { turnedOn.mode = .sendAllowed }
        center.setRule(turnedOn, for: app.id)
        // Turned on six days ago, so every fixture counts as new.
        center.update(app.id) { $0.rule.onSince = now.addingTimeInterval(-6 * 86400) }
        return (center, notifier)
    }

    /// de1 (1★, a day ago) and a 5★ from today.
    private func reviews() -> ReviewsStore {
        ReviewsTestData.store(reviews: [
            ReviewsTestData.review("de1", "DE", rating: 1, language: "de", daysAgo: 1),
            ReviewsTestData.review("us5", "US", rating: 5, language: "en", daysAgo: 0.1),
            ReviewsTestData.review("old", "US", rating: 5, language: "en", daysAgo: 5),
        ])
    }

    private func receive(_ ids: [String], into center: AutoReplyCenter, store: ReviewsStore, flags: [String: Set<AutoReplyTopic>] = [:]) {
        let suggestions = ids.map { ReviewsTestData.suggestion($0, text: "Thank you for writing!") }
        store.add(suggestions, for: app.id)
        center.received(
            suggestions, flags: flags.mapValues { ($0, false) }, reviews: store.archive(for: app.id), app: app
        )
    }

    @Test func turningItOnAnswersReviewsFromNowOn() {
        let center = AutoReplyCenter()
        center.now = { now }
        var rule = AutoReplyRule()
        rule.isOn = true
        center.setRule(rule, for: app.id)
        #expect(center.rule(for: app.id).onSince == now)
        #expect(center.isActive(for: app.id))
        center.setPaused(true, for: app.id)
        #expect(!center.isActive(for: app.id))
    }

    @Test func arrivingRepliesAreDecidedAndTheWaitingOnesTold() {
        let (center, notifier) = center()
        let store = reviews()
        receive(["de1", "us5"], into: center, store: store)
        #expect(center.draft(for: "us5", appID: app.id)?.state.isScheduled == true)
        #expect(center.draft(for: "de1", appID: app.id)?.state == .needsYou(reason: "1★ replies wait for you"))
        #expect(center.needsYouCount(for: app.id) == 1)
        #expect(notifier.sent.count == 1)
        #expect(notifier.sent.first?.title == "A 1★ review needs your reply")
        #expect(notifier.sent.first?.category == .autoReplyNeedsYou)
    }

    /// Draft and tell me: the notification shows the reply, with Send Reply.
    @Test func aDraftedReplyIsToldWithItsText() {
        var rule = AutoReplyRule()
        rule.mode = .draftAndTell
        let (center, notifier) = center(rule: rule)
        let store = reviews()
        receive(["us5"], into: center, store: store)
        #expect(center.draft(for: "us5", appID: app.id)?.state == .drafted)
        let told = notifier.sent.first
        #expect(told?.category == .autoReplyReady)
        #expect(told?.body.hasSuffix("Reply: “Thank you for writing!”") == true)
    }

    @Test func reviewsFromBeforeItWasOnAreLeftAlone() {
        let (center, _) = center()
        center.update(app.id) { $0.rule.onSince = now }
        let store = reviews()
        receive(["us5"], into: center, store: store)
        #expect(center.draft(for: "us5", appID: app.id) == nil)
    }

    /// The menu bar's Pause Auto-Reply: every app that has it on.
    @Test func theMenuBarPausesEveryApp() {
        let (center, _) = center()
        let other: StoreApp.ID = "other"
        #expect(center.pausedState(for: [other]) == nil, "Not on there")
        #expect(center.pausedState(for: [app.id, other]) == false)
        center.setPaused(true, forAll: [app.id, other])
        #expect(center.pausedState(for: [app.id, other]) == true)
        #expect(!center.rule(for: other).isPaused, "Off stays off")
    }

    @Test func pausedRepliesWait() {
        let (center, _) = center()
        center.setPaused(true, for: app.id)
        let store = reviews()
        receive(["us5"], into: center, store: store)
        #expect(center.draft(for: "us5", appID: app.id)?.state.needsYou == true)
    }

    @Test func freeDoesNothing() {
        let (center, _) = center(isPro: false)
        let store = reviews()
        receive(["us5"], into: center, store: store)
        #expect(center.draft(for: "us5", appID: app.id) == nil)
        #expect(center.needsYouCount(for: app.id) == 0)
    }

    @Test func nothingGoesOutBeforeAReplyWasSentByHand() async {
        let (center, _) = center()
        let store = reviews()
        receive(["us5"], into: center, store: store)
        center.now = { now.addingTimeInterval(2 * 3600) }
        let services = FakeReviewsServices()
        await center.sendDue(app: app, reviews: store, services: services)
        #expect(services.sent.isEmpty)
        #expect(center.sendingHold(for: app.id, reviews: store)?.contains("your first reply") == true)

        store.markReplySentByHand()
        await center.sendDue(app: app, reviews: store, services: services)
        #expect(services.sent.map(\.reviewID) == ["us5"])
        #expect(store.archive(for: app.id).review(id: "us5")?.hasReply == true)
        #expect(center.archive(for: app.id).history.first?.reviewID == "us5")
        #expect(center.sentToday(for: app.id) == 1)
    }

    @Test func aReplyWaitsUntilItsTime() async {
        let (center, _) = center()
        let store = reviews()
        store.markReplySentByHand()
        receive(["us5"], into: center, store: store)
        let services = FakeReviewsServices()
        await center.sendDue(app: app, reviews: store, services: services)
        #expect(services.sent.isEmpty, "Its hour isn't over")
    }

    @Test func theDaysCapHoldsTheRest() async {
        var rule = AutoReplyRule()
        rule.mode = .sendAllowed
        rule.dailyCap = 1
        let (center, _) = center(rule: rule)
        let store = reviews()
        store.markReplySentByHand()
        receive(["us5", "old"], into: center, store: store)
        center.now = { now.addingTimeInterval(2 * 3600) }
        let services = FakeReviewsServices()
        await center.sendDue(app: app, reviews: store, services: services)
        #expect(services.sent.count == 1)
        #expect(center.sendingHold(for: app.id, reviews: store)?.contains("the rest go tomorrow") == true)
    }

    @Test func aRefusedReplyWaitsWithAppleReason() async {
        let (center, _) = center()
        let store = reviews()
        store.markReplySentByHand()
        receive(["us5"], into: center, store: store)
        center.now = { now.addingTimeInterval(2 * 3600) }
        let services = FakeReviewsServices()
        services.refused = ["us5"]
        await center.sendDue(app: app, reviews: store, services: services)
        #expect(center.draft(for: "us5", appID: app.id)?.state.needsYou == true)
    }

    @Test func undoTakesItOffTheAppStoreAndKeepsTheDraft() async throws {
        let (center, _) = center()
        let store = reviews()
        store.markReplySentByHand()
        receive(["us5"], into: center, store: store)
        center.now = { now.addingTimeInterval(2 * 3600) }
        let services = FakeReviewsServices()
        await center.sendDue(app: app, reviews: store, services: services)
        let entry = try #require(center.archive(for: app.id).history.first)
        try await center.undo(entry, app: app, reviews: store, services: services)
        #expect(services.deleted == [entry.replyID])
        #expect(store.archive(for: app.id).review(id: "us5")?.hasReply == false)
        #expect(center.draft(for: "us5", appID: app.id)?.state == .held)
        #expect(center.archive(for: app.id).history.first?.undoneAt != nil)
        #expect(center.sentToday(for: app.id) == 0, "Undone replies don't count")
    }

    @Test func dontSendAndTheirOwnReplyStopIt() {
        let (center, _) = center()
        let store = reviews()
        receive(["us5", "old"], into: center, store: store)
        center.hold("us5", appID: app.id)
        #expect(center.draft(for: "us5", appID: app.id)?.state == .held)
        center.personReplied(to: "old", appID: app.id)
        #expect(center.draft(for: "old", appID: app.id) == nil)
    }

    @Test func turningItOffHoldsWhatWasScheduled() {
        let (center, _) = center()
        let store = reviews()
        receive(["us5"], into: center, store: store)
        var rule = center.rule(for: app.id)
        rule.isOn = false
        center.setRule(rule, for: app.id)
        #expect(center.draft(for: "us5", appID: app.id)?.state == .held)
    }

    @Test func onlyNewReviewsWithoutAReplyAreWritten() {
        let (center, _) = center()
        let store = reviews()
        let archive = store.archive(for: app.id)
        #expect(Set(center.reviewsToWrite(for: app.id, reviews: archive).map(\.id)) == ["de1", "us5", "old"])
        receive(["de1"], into: center, store: store)
        center.update(app.id) { $0.requested["us5"] = now }
        #expect(center.reviewsToWrite(for: app.id, reviews: store.archive(for: app.id)).map(\.id) == ["old"])
    }

    @Test func theAssistantsFlagsAreRead() {
        let value: JSONValue = ["reviewId": "a", "text": "Hi", "waitTopics": ["bug", "nonsense", "billing"], "unsure": true]
        let flags = ProposeReviewRepliesTool.flags(value)
        #expect(flags.topics == [.bug, .billing])
        #expect(flags.isUnsure)
        #expect(ProposeReviewRepliesTool.flags(["reviewId": "a"]).topics.isEmpty)
    }

    @Test func theRuleSaysWhatGoesOut() {
        var rule = AutoReplyRule()
        #expect(rule.summary == "Drafts a reply to each new review and tells you")
        rule.mode = .sendAllowed
        #expect(rule.summary == "4★ and 5★ in every language go out after 1 hour")
    }

    @Test func theCountdownSaysWhen() {
        #expect(ReviewSuggestionBox.sendsText(now.addingTimeInterval(42 * 60), now: now) == "Sends by itself in 42 min")
        #expect(ReviewSuggestionBox.sendsText(now.addingTimeInterval(-5), now: now) == "Sends by itself in a moment")
    }
}
