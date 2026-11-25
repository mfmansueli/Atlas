//
//  TourStep.swift
//  Atlas
//

import Foundation

/// The first-run tour's tips (board 63), one at a time, in order: the app
/// switcher, the sections, the Autopilot bar, Review & Push and the
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
            String(localized: "Click to switch apps. The last line shows when another app has suggestions.")
        case .sections:
            String(localized: "A purple number counts the suggestions waiting there. Overview shows them all.")
        case .autopilot:
            String(
                localized: "Asks your assistant for this section’s texts, screenshots, prices or replies. Or do it by hand."
            )
        case .reviewPush:
            String(localized: "Everything you accept or edit waits here until you push it.")
        case .settings:
            String(localized: "Connect your assistant, add accounts and choose notifications. ⌘, opens it too.")
        }
    }

    /// The tip's symbol (board 63 after the SF Symbols pass): what the tip
    /// points at, as the app draws it.
    var systemImage: String {
        switch self {
        case .apps: "apps.iphone"
        case .sections: "sidebar.left"
        case .autopilot: "sparkles"
        case .reviewPush: "arrow.up.circle"
        case .settings: "gearshape"
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
