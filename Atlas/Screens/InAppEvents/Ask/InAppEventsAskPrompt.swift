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

    /// What the toolbar and the toast say the request is about.
    static var subject: String { String(localized: "In-App Events", comment: "kind:label") }

    /// The toast once the run finished: where the texts are.
    static func done(client: String) -> String {
        String(localized: "\(client) finished. Its event texts are marked in purple.", comment: "kind:toast")
    }

    /// Suggest an Event… (board 74 · 3): the toolbar's lead while the
    /// app has no event. The event waits in Review & Push to be made.
    static func suggest(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: purpose,
            prompt: String(localized: """
            Suggest a first In-App Event for \(app) in Atlas. Read get_in_app_events for what's queued already, \
            get_app_versions and get_listing with fields ["whatsNew"] for what's coming, and this project for something \
            timely people can do in the app: a challenge, a new season, a live session, a major update. Send one with \
            propose_in_app_event: a reference name, the badge, the dates (starting at least 2 days from now for App Review, \
            lasting at most 31 days) and the texts in the primary language, with its deep link when you know it. Say why \
            in one sentence. Never submit; the person pushes it and adds the images. \
            \(StoreTextGuidelinePlace.eventText.summary)
            """, comment: "kind:other"),
            subject: String(localized: "In-App Events · a new event", comment: "kind:other"),
            done: String(localized: "Done. The event waits in Review & Push to be made.", comment: "kind:toast")
        )
    }

    static func text(app: String) -> String {
        String(localized: """
        Suggest the texts of \(app)’s In-App Events in Atlas. Read them with get_in_app_events: each event’s name \
        (30 characters), short description (50) and long description (120) in its primary language, and the languages \
        still missing. For every missing language write all three in that language, natural rather than literal (a winter \
        event isn’t one where December is summer), in the voice of that language’s store page, within the limits, and send \
        them with propose_event_texts with one sentence on why they read this way. Leave the languages that are written. \
        \(StoreTextGuidelinePlace.eventText.summary)
        """)
    }
}
