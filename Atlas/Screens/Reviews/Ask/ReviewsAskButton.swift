//
//  ReviewsAskButton.swift
//  Atlas
//

import SwiftUI

/// "Ask Claude Code…" in Reviews: suggests a reply for each review that
/// needs one and groups the reviews by subject.
struct ReviewsAskButton: View {
    let app: StoreApp

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: ReviewsAskPrompt.purpose,
            prompt: ReviewsAskPrompt.text(app: app.name),
            help: { client in String(localized: "Ask \(client) to suggest replies, each in the reviewer’s language, and to group the reviews") },
            explanation: { client in
                String(localized: """
                \(client) reads \(app.name)’s reviews and its project, suggests a reply under each review that needs one \
                and groups them by subject. Nothing is sent until you press Send Reply.
                """)
            },
            identifier: "reviews.ask"
        )
    }
}
