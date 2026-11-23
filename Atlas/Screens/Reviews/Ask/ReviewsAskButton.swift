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
            help: { client in String(localized: "Asks \(client) for replies in each reviewer’s language, grouped by subject") },
            explanation: { client in
                String(localized: "\(client) suggests replies to \(app.name)’s reviews and groups them by subject. Nothing is sent until you press Send Reply.")
            },
            identifier: "reviews.ask"
        )
    }
}
