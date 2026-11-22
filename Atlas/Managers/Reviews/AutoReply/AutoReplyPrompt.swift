//
//  AutoReplyPrompt.swift
//  Atlas
//

import Foundation

/// What Reply Automatically starts Claude Code with on a check (board
/// 58): reply to these new reviews in their own language, in the rule's
/// tone, and say for each what it's about, so the rule can decide which
/// ones wait for the person.
enum AutoReplyPrompt {
    static func text(app: String, reviewIDs: [AppReview.ID], rule: AutoReplyRule) -> String {
        let topics = AutoReplyTopic.allCases.map(\.key).joined(separator: ", ")
        let signature = rule.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        let sign = signature.isEmpty ? "" : " End each reply with “— \(signature)” on its own line."
        return String(localized: """
        Reply Automatically is on for \(app) in Atlas. Read these new reviews with get_reviews (show: needsReply): \
        \(reviewIDs.joined(separator: ", ")). For each, write a reply in the reviewer’s own language, \(rule.tone.instruction), \
        specific to what they wrote, and send them with propose_review_replies, each with what it means in English. \
        For every reply also send waitTopics, the ones the review is about from: \(topics) (empty when none), and \
        unsure: true when you aren’t sure what the reviewer means. Read the project to say what is fixed or planned, \
        and never promise what isn’t there.\(sign) \(StoreTextGuidelinePlace.reviewReply.summary) Never mention prices, \
        offers, other apps or dates for new features, and never ask for a better rating. Atlas decides which replies go \
        out by themselves from the person’s rule; you never send one, and you can’t change the rule.
        """)
    }
}
