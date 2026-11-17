//
//  ReviewsAskPrompt.swift
//  Atlas
//

import Foundation

/// What "Ask Claude Code…" in Reviews starts Claude Code with, or copies:
/// suggest a reply for every review that needs one, in the reviewer's
/// language, and group the reviews by subject.
enum ReviewsAskPrompt {
    /// The run's purpose, so the button finds its own run.
    static var purpose: ClaudeCodeRunPurpose { .ask(area: String(localized: "Reviews")) }

    static func text(app: String) -> String {
        String(localized: """
        Suggest replies to \(app)’s App Store reviews in Atlas. Read them with get_reviews. For each review \
        that needs a reply, write one in the reviewer’s own language, short and specific to what they wrote, and send \
        it with propose_review_replies together with what it means in English. Read the project to say what is fixed \
        or planned, and never promise what isn’t there. Then group the reviews by subject with propose_review_themes: \
        what’s broken, what people ask for, what they love, each with one action and, for reply_to_all, one message per \
        language. Nothing reaches the App Store from you: the person sends each reply.
        """)
    }
}
