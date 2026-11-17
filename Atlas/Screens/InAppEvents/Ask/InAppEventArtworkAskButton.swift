//
//  InAppEventArtworkAskButton.swift
//  Atlas
//

import SwiftUI

/// "Ask Claude Code…" on an event's Images and video: makes the event's
/// card and details page, checks them and queues them here to accept.
struct InAppEventArtworkAskButton: View {
    let app: StoreApp
    let event: InAppEvent

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: InAppEventArtworkAskPrompt.purpose(eventID: event.id),
            prompt: InAppEventArtworkAskPrompt.text(app: app.name, appID: app.id, event: event.referenceName, eventID: event.id),
            help: { client in String(localized: "Ask \(client) to make this event’s card and details page") },
            explanation: { client in
                String(localized: """
                \(client) makes “\(event.referenceName)”’s card and details page, from the app’s own visuals when its \
                project draws them, checks them against Apple’s rules under the event’s text, and sends them here. \
                Each waits for you to accept it; accepted, it waits in Review & Push.
                """)
            },
            identifier: "events.media.ask"
        )
    }
}
