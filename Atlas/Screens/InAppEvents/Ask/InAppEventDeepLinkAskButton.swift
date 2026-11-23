//
//  InAppEventDeepLinkAskButton.swift
//  Atlas
//

import SwiftUI

/// Check in the Code, or Make It Work…: Claude Code checks in the
/// project that the app opens the event's deep link the way App Review
/// tries it (first making it do so, for Make It Work…), and reports it
/// here with `report_deep_link_check`.
struct InAppEventDeepLinkAskButton: View {
    let app: StoreApp
    let event: InAppEvent
    let deepLink: String?
    let kind: InAppEventDeepLinkAskPrompt.Kind
    /// `events.deepLink.check`; the popover adds `.popover`.
    let identifier: String

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: InAppEventDeepLinkAskPrompt.purpose(kind, eventID: event.id),
            prompt: InAppEventDeepLinkAskPrompt.text(kind, app: app.name, appID: app.id, event: event, deepLink: deepLink),
            help: { client in
                kind == .check
                    ? String(localized: "Ask \(client) whether \(app.name) opens this event’s deep link")
                    : String(localized: "Ask \(client) to make \(app.name) open this event’s deep link")
            },
            explanation: { client in
                kind == .check
                    ? String(localized: """
                    \(client) builds \(app.name) and tries the link in Simulator. It reports whether the event opens before \
                    its start, after onboarding, without a paywall. Changes nothing.
                    """)
                    : String(localized: """
                    \(client) makes \(app.name) open the event from the link, tests it in Simulator and bumps the build \
                    number. You upload the build from Xcode.
                    """)
            },
            identifier: identifier,
            title: { _ in kind == .check ? String(localized: "Check in the Code") : String(localized: "Make It Work…") },
            subject: String(localized: "In-App Event deep link"),
            done: { client in String(localized: "\(client) checked the deep link. It’s on the event’s page.") }
        )
    }
}
