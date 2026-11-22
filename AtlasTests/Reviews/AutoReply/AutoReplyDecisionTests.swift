//
//  AutoReplyDecisionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which automatic replies go out by themselves (board 58): only what the
/// rule allows, Claude read nothing that waits and was sure, and the
/// reply passes App Review's rules; the rest wait, with the reason.
@MainActor
@Suite("AutoReplyDecision")
struct AutoReplyDecisionTests {
    private let now = ReviewsTestData.now

    private var sending: AutoReplyRule {
        var rule = AutoReplyRule()
        rule.isOn = true
        rule.mode = .sendAllowed
        return rule
    }

    private func state(
        _ review: AppReview, text: String = "Thank you for writing!", topics: Set<AutoReplyTopic> = [], unsure: Bool = false,
        rule: AutoReplyRule? = nil
    ) -> AutoReplyDraftState {
        AutoReplyDecision.state(for: review, text: text, topics: topics, isUnsure: unsure, rule: rule ?? sending, now: now)
    }

    @Test func draftAndTellNeverSends() {
        var rule = sending
        rule.mode = .draftAndTell
        #expect(state(ReviewsTestData.review("a", rating: 5, daysAgo: 0), rule: rule) == .drafted)
    }

    @Test func anAllowedReplyGoesOutAfterTheWait() {
        let review = ReviewsTestData.review("a", rating: 5, daysAgo: 0)
        #expect(state(review) == .scheduled(sendAt: now.addingTimeInterval(60 * 60)))
        var rule = sending
        rule.delay = .quarterHour
        #expect(state(review, rule: rule) == .scheduled(sendAt: now.addingTimeInterval(15 * 60)))
    }

    @Test func aTopicThatWaitsWaitsWithItsReason() {
        let review = ReviewsTestData.review("a", rating: 5, daysAgo: 0)
        #expect(state(review, topics: [.bug]) == .needsYou(reason: "it mentions a bug or crash"))
        var rule = sending
        rule.waitTopics = [.billing]
        #expect(state(review, topics: [.bug], rule: rule).isScheduled, "Bugs don't wait under this rule")
    }

    @Test func anUnsureReadWaits() {
        #expect(state(ReviewsTestData.review("a", rating: 5, daysAgo: 0), unsure: true).needsYou)
    }

    @Test func ratingsAndLanguagesOutsideTheRuleWait() {
        #expect(state(ReviewsTestData.review("a", rating: 1, daysAgo: 0)) == .needsYou(reason: "1★ replies wait for you"))
        var rule = sending
        rule.languages = ["de"]
        #expect(state(ReviewsTestData.review("a", rating: 5, language: "ja", daysAgo: 0), rule: rule).needsYou)
        #expect(state(ReviewsTestData.review("b", rating: 5, language: "de", daysAgo: 0), rule: rule).isScheduled)
    }

    @Test func nothingOlderThanAWeekGoesOut() {
        #expect(state(ReviewsTestData.review("a", rating: 5, daysAgo: 8)) == .needsYou(reason: "it’s more than a week old"))
    }

    @Test func aReplyThatBreaksAppReviewsRulesWaits() {
        let review = ReviewsTestData.review("a", rating: 5, daysAgo: 0)
        #expect(state(review, text: "Thanks! Pro is only $4.99 this week.").needsYou)
    }
}
