//
//  InAppEventsAskButton.swift
//  Atlas
//

import SwiftUI

/// "Ask Claude Code…" in In-App Events: suggests each event's texts in the
/// languages it doesn't have yet.
struct InAppEventsAskButton: View {
    let app: StoreApp

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: InAppEventsAskPrompt.purpose,
            prompt: InAppEventsAskPrompt.text(app: app.name),
            help: { client in String(localized: "Ask \(client) to write each event in the languages it’s missing") },
            explanation: { client in
                String(localized: """
                \(client) reads \(app.name)’s events and its store page, and suggests each event’s three texts in every \
                language that’s missing. They wait here as suggestions; accepted, they wait in Review & Push.
                """)
            },
            identifier: "events.ask"
        )
    }
}
