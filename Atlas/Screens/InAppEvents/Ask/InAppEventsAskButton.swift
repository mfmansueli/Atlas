//
//  InAppEventsAskButton.swift
//  Atlas
//

import SwiftUI

/// "Ask Claude Code…" in In-App Events: suggests each event's texts in the
/// languages it doesn't have yet. From an event's page the toolbar names
/// the event: "In-App Events · Winter Reflection 2026".
struct InAppEventsAskButton: View {
    let app: StoreApp
    var event: InAppEvent?

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
            identifier: event == nil ? "events.ask" : "events.page.ask",
            subject: event.map { String(localized: "In-App Events · \($0.referenceName)") }
        )
    }
}
