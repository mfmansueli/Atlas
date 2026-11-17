//
//  InAppEventsAskPrompt.swift
//  Atlas
//

import Foundation

/// What "Ask Claude Code…" in In-App Events starts Claude Code with, or
/// copies: write each event's texts in the languages still missing.
enum InAppEventsAskPrompt {
    /// The run's purpose, so the button finds its own run.
    static var purpose: ClaudeCodeRunPurpose { .ask(area: String(localized: "In-App Events")) }

    static func text(app: String) -> String {
        String(localized: """
        Suggest the texts of \(app)’s In-App Events in Atlas. Read them with get_in_app_events: each event’s name \
        (30 characters), short description (50) and long description (120) in its primary language, and the languages \
        still missing. For every missing language write all three in that language, natural rather than literal (a winter \
        event isn’t one where December is summer), in the voice of that language’s store page, within the limits, and send \
        them with propose_event_texts with one sentence on why they read this way. Leave the languages that are written.
        """)
    }
}
