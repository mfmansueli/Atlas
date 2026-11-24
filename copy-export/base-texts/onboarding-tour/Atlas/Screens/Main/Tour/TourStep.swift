//
//  TourStep.swift
//  Atlas
//

import Foundation

/// The first-run tour's tips (board 63), one at a time, in order: the app
/// switcher, the sections, the Autopilot button, Review & Push and the
/// sidebar's Settings row.
enum TourStep: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case apps
    case sections
    case autopilot
    case reviewPush
    case settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .apps: String(localized: "Your apps are here")
        case .sections: String(localized: "Each section is a part of your App Store page")
        case .autopilot: String(localized: "Let your assistant do the work")
        case .reviewPush: String(localized: "Nothing changes until you push")
        case .settings: String(localized: "Settings are always here")
        }
    }

    var text: String {
        switch self {
        case .apps:
            String(localized: "Click to switch to another app. The last line tells you when another app has suggestions for you.")
        case .sections:
            String(localized: "A purple number is how many suggestions are waiting there. Overview shows them all in one place.")
        case .autopilot:
            String(
                localized: "This button asks Claude Code for what the section needs: texts, screenshots, prices or replies. You can always do the same by hand."
            )
        case .reviewPush:
            String(localized: "What you accept or edit waits here. Review & Push shows every change before it goes to the App Store.")
        case .settings:
            String(localized: "Connect your assistant, add accounts and choose notifications. ⌘, opens it too.")
        }
    }

    /// The glyph on the tip's tinted tile.
    var systemImage: String {
        switch self {
        case .apps: "plus.square"
        case .sections: "doc.plaintext"
        case .autopilot: "sparkles"
        case .reviewPush: "arrow.up.circle"
        case .settings: "circle.circle"
        }
    }

    /// 1 for the first tip.
    var number: Int { rawValue + 1 }

    /// "1 of 5".
    var countText: String {
        String(localized: "\(number) of \(Self.allCases.count)")
    }

    /// The tip after this one; nil after the last.
    var next: TourStep? { TourStep(rawValue: rawValue + 1) }

    var isLast: Bool { next == nil }

    /// "Next", or "Done" on the last tip.
    var nextTitle: String {
        isLast ? String(localized: "Done") : String(localized: "Next")
    }

    /// "Skip the Tour", or on the last tip "Connect an Assistant…", which
    /// ends the tour on Settings → AI Assistants.
    var alternativeTitle: String {
        isLast ? String(localized: "Connect an Assistant…") : String(localized: "Skip the Tour")
    }
}
