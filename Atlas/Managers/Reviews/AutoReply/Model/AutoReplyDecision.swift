//
//  AutoReplyDecision.swift
//  Atlas
//

import Foundation

/// What happens to a reply Claude wrote for a new review, by the rule
/// (board 58): it goes out by itself after the wait only when the rule
/// sends, the rating and language are allowed, Claude read no topic that
/// waits and was sure, and it passes App Review's rules for replies;
/// otherwise it waits for the person, with the reason.
enum AutoReplyDecision {
    static func state(
        for review: AppReview, text: String, topics: Set<AutoReplyTopic>, isUnsure: Bool, rule: AutoReplyRule, now: Date
    ) -> AutoReplyDraftState {
        guard rule.mode == .sendAllowed else { return .drafted }
        if let reason = waitReason(for: review, text: text, topics: topics, isUnsure: isUnsure, rule: rule, now: now) {
            return .needsYou(reason: reason)
        }
        return .scheduled(sendAt: now.addingTimeInterval(rule.delay.interval))
    }

    /// Why it can't go out by itself, nil when it can.
    static func waitReason(
        for review: AppReview, text: String, topics: Set<AutoReplyTopic>, isUnsure: Bool, rule: AutoReplyRule, now: Date
    ) -> String? {
        if let topic = AutoReplyTopic.allCases.first(where: { topics.contains($0) && rule.waitTopics.contains($0) }) {
            return topic.reason
        }
        if isUnsure { return String(localized: "Claude wasn’t sure what it means") }
        if !rule.ratings.contains(review.rating) {
            return String(localized: "\(review.rating)★ replies wait for you")
        }
        if !rule.languages.isEmpty, !rule.languages.contains(review.languageCode) {
            let name = review.languageCode.isEmpty ? String(localized: "this language") : ReviewLanguage.name(of: review.languageCode)
            return String(localized: "replies in \(name) wait for you")
        }
        if now.timeIntervalSince(review.date) > AutoReplyRule.maximumAge {
            return String(localized: "it’s more than a week old")
        }
        let issues = StoreTextGuidelineCheck.issues(in: text, for: .reviewReply)
        if let issue = issues.first {
            return String(localized: "the reply breaks a rule for replies: \(issue.message)")
        }
        return nil
    }
}
