//
//  InAppEventsAskButton.swift
//  Atlas
//

import SwiftUI

/// "Ask Claude Code…" in the events gallery's header (board 40, `ask-ev`):
/// Claude Code writes every event's texts in the languages still missing.
/// The request flies to the toolbar's Autopilot button, which says
/// Working… until the run ends (board 56); the same request is the
/// Autopilot menu's Write Event Texts….
struct InAppEventsAskButton: View {
    let app: StoreApp

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: InAppEventsAskPrompt.purpose,
            prompt: InAppEventsAskPrompt.text(app: app.name),
            help: { client in String(localized: "Ask \(client) to write the events’ texts in the missing languages", comment: "kind:tooltip") },
            explanation: { client in
                String(localized: """
                \(client) writes each event’s name and descriptions in the languages still missing. Accept each on the \
                event’s page; accepted ones wait in Review & Push.
                """, comment: "kind:body")
            },
            identifier: "events.ask",
            subject: InAppEventsAskPrompt.subject,
            done: { client in InAppEventsAskPrompt.done(client: client) }
        )
    }
}
