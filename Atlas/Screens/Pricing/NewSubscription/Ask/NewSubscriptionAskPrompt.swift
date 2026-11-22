//
//  NewSubscriptionAskPrompt.swift
//  Atlas
//

import Foundation

/// What "Ask Claude Code…" in Pricing starts Claude Code with, or copies:
/// read the subscriptions and in-app purchases the app's code sells and
/// propose the ones App Store Connect doesn't have, with their offers and
/// review screenshots.
enum NewSubscriptionAskPrompt {
    /// The run's purpose, so the button finds its own run.
    static var purpose: ClaudeCodeRunPurpose { .ask(area: String(localized: "Subscriptions")) }

    /// "Set up the subscriptions of Bruma in Atlas: …".
    static func text(app: String) -> String {
        String(localized: """
        Set up the subscriptions of \(app) in Atlas. Read the app's project for what it sells: the product \
        IDs its StoreKit code or .storekit configuration buys, each one's duration, and what the paywall says it \
        unlocks. Check get_subscriptions for what App Store Connect already has, then propose each missing subscription \
        with propose_subscription: its group, reference name, the product ID exactly as the code uses it, duration, \
        display name and description, and a starting price in US dollars (the paywall's or the .storekit file's \
        when there is one). Propose a lifetime unlock or other one-time purchase with propose_in_app_purchase, and \
        a free trial or intro price the paywall promises with propose_introductory_offer. Every product needs an \
        App Review screenshot of the paywall: send the image to get_subscriptions' reviewScreenshotUploadURL and \
        pass its fileId as reviewScreenshot, or later with propose_purchase_review_screenshot. Pass evidence as \
        "file:line — finding". Don't propose what's already there. \
        \(StoreTextRules.inAppSummary)
        """)
    }
}
