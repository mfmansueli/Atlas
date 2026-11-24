//
//  InAppEventDeepLinkAskPrompt.swift
//  Atlas
//

import Foundation

/// What Check in the Code and Make It Work… start Claude Code with, or
/// copy: check in the person's project that the app opens an event's deep
/// link the way App Review tries it, and report it with
/// `report_deep_link_check`; or first make it do so.
enum InAppEventDeepLinkAskPrompt {
    enum Kind: Hashable, Sendable {
        /// Check in the Code: read, build and try; change nothing.
        case check
        /// Make It Work…: change the project, then check.
        case makeItWork
    }

    static func purpose(_ kind: Kind, eventID: String) -> ClaudeCodeRunPurpose {
        switch kind {
        case .check: .deepLinkCheck(eventID: eventID)
        case .makeItWork: .deepLinkWork(eventID: eventID)
        }
    }

    /// What the link must do: on a cold launch and with the app open,
    /// after onboarding, before the event starts (App Review taps Open
    /// then), never on a paywall for a free event, home for one it doesn't
    /// know.
    static func requirements(isFree: Bool) -> String {
        var lines = [
            "it opens the event on a cold launch and when the app is already open, in the foreground or the background",
            "it works after onboarding: a person who hasn't finished it lands on the event once they do, not on a plain home",
            "before the event starts it shows the event and its start date, never a plain screen: App Review taps Open before the event begins",
            "an unknown or ended event opens the normal home screen",
        ]
        if isFree { lines.insert("the event costs nothing (NO_COST_ASSOCIATED), so the link never lands on a paywall", at: 3) }
        return lines.map { "- \($0)" }.joined(separator: "\n")
    }

    static func text(_ kind: Kind, app: String, appID: String, event: InAppEvent, deepLink: String?) -> String {
        let isFree = (event.purchaseRequirement ?? .noCostAssociated) == .noCostAssociated
        let name = event.primaryLocalization?.name.isEmpty == false ? event.primaryLocalization?.name ?? event.referenceName : event.referenceName
        let link = deepLink.map { "its deep link \($0)" } ?? "a deep link (it has none yet)"
        let start = String(localized: """
        \(app)’s In-App Event “\(name)” (app \(appID), event \(event.id)) needs \(link) to work: Open on the event's card \
        and details page goes there, and App Review taps it. Read the event with get_in_app_events: its deepLink, \
        deepLinkClaim (whether the project claims its URL scheme or domain), dates and purchaseRequirement.
        """)
        let pick = deepLink == nil ? String(localized: """
        First choose a deep link that fits how the app takes links (its URL scheme, or a universal link on a domain \
        in its Associated Domains) and names this event, and propose it with propose_event_details: the person accepts \
        it in Atlas.
        """) : ""
        let check = String(localized: """
        Find where the app takes incoming links (onOpenURL, application(_:open:options:), scene(_:openURLContexts:), \
        an NSUserActivity for universal links) and check the URL scheme in the Info.plist's URL types or the domain in \
        the Associated Domains entitlement. The link must work like this:
        \(requirements(isFree: isFree))
        """)
        let report = String(localized: """
        Report it with report_deep_link_check: whether it opens the event, what the person sees, what it shows before the \
        event starts, whether it needs Premium, where the link is handled (file:line), the build you checked as \
        MARKETING_VERSION (CURRENT_PROJECT_VERSION), whether you tried it in Simulator, and each problem left. Never push \
        and never submit the event for review: the person does.
        """)
        switch kind {
        case .check:
            return [start, pick, check, String(localized: """
            Check it in the code without changing the project. When you can build the app for a simulator, install it and \
            try the link with xcrun simctl openurl booted '<link>', on a cold launch and with the app open.
            """), report].filter { !$0.isEmpty }.joined(separator: "\n\n")
        case .makeItWork:
            return [start, pick, check, String(localized: """
            Make it work in the project: declare the URL scheme or domain when it's missing, handle the link, and open \
            the event's screen. Build it for a simulator and test it with xcrun simctl openurl booted '<link>', on a cold \
            launch and with the app open. Then bump the build number (CURRENT_PROJECT_VERSION) by one, so the next upload \
            carries it, and don't archive or upload the build: the person uploads it.
            """), report].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
    }
}
