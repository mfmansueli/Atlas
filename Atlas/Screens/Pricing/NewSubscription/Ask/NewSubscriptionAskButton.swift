//
//  NewSubscriptionAskButton.swift
//  Atlas
//

import SwiftUI

/// "Ask Claude Code…" in Pricing: reads the subscriptions the app's code
/// sells and proposes the ones App Store Connect doesn't have.
struct NewSubscriptionAskButton: View {
    let app: StoreApp

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: NewSubscriptionAskPrompt.purpose,
            prompt: NewSubscriptionAskPrompt.text(app: app.name),
            help: { client in String(localized: "Ask \(client) to set up the subscriptions \(app.name)’s code sells") },
            explanation: { client in
                String(localized: "\(client) suggests the subscriptions \(app.name)’s code sells. They wait in Review & Push until you push.")
            },
            identifier: "pricing.newSubscription.ask"
        )
    }
}
