//
//  PaywallContext.swift
//  Atlas
//

import Foundation

/// Why the paywall opened: the action that needed Pro, in the person's own
/// numbers, or the toolbar's Pro button (`menu`, no card). The card says
/// what was blocked and that the one-at-a-time way stays free.
enum PaywallContext: Hashable, Sendable {
    case acceptAllLanguages(suggestions: Int, languages: Int)
    case acceptAllPages(suggestions: Int, pages: Int)
    case translateAll(languages: Int)
    case autopilot
    case recommendedPrices(countries: Int)
    case retention
    case secondApp
    case template
    /// Make the Artwork… on an In-App Event.
    case eventArtwork
    case menu

    /// The feature highlighted in the paywall's list.
    var feature: ProFeature? {
        switch self {
        case .acceptAllLanguages, .acceptAllPages, .translateAll: .acceptAll
        case .autopilot, .eventArtwork: .autopilot
        case .recommendedPrices: .recommendedPrices
        case .retention: .retention
        case .secondApp: .multipleApps
        case .template: .allTemplates
        case .menu: nil
        }
    }

    /// "Accept All Languages is part of Pro".
    var title: String? {
        switch self {
        case .acceptAllLanguages: String(localized: "Accept All Languages is part of Pro")
        case .acceptAllPages: String(localized: "Accept All Pages is part of Pro")
        case .translateAll: String(localized: "Translate All is part of Pro")
        case .autopilot: String(localized: "Autopilot is part of Pro")
        case .recommendedPrices: String(localized: "Suggested prices are part of Pro")
        case .retention: String(localized: "Retention is part of Pro")
        case .secondApp: String(localized: "More than one app is part of Pro")
        case .template: String(localized: "This template is part of Pro")
        case .eventArtwork: String(localized: "Event artwork is part of Pro")
        case .menu: nil
        }
    }

    var detail: String? {
        switch self {
        case let .acceptAllLanguages(suggestions, languages):
            String(localized: "Accept \(suggestions) suggestions in \(languages) languages at once. One at a time stays free.")
        case let .acceptAllPages(suggestions, pages):
            String(localized: "Accept \(suggestions) suggestions on \(pages) pages at once. One at a time stays free.")
        case let .translateAll(languages):
            String(localized: "Translate what’s missing in \(languages) languages at once. One language at a time stays free.")
        case .autopilot:
            String(localized: "Screenshots, App Preview and header artwork in every language, made in the background. Editing yourself stays free.")
        case let .recommendedPrices(countries):
            String(localized: "Set \(countries) prices for local purchasing power at once, previewed per country. Your own prices stay free.")
        case .retention:
            String(localized: "Messages and offers for people who are about to cancel, in every language.")
        case .secondApp:
            String(localized: "All your apps and App Store Connect accounts in one window. Your first app, and its work, stays free.")
        case .template:
            String(localized: "All 14 templates for every device: Mac, iPad, iPhone Duo, Vision Pro, Apple Watch. 3 iPhone and iPad templates stay free.")
        case .eventArtwork:
            String(localized: "A matching event card and details image, in three concepts. Using your own files stays free.")
        case .menu: nil
        }
    }

    /// After buying, the button that finishes what they started: "Accept
    /// 32 Suggestions…".
    var continueTitle: String? {
        switch self {
        case let .acceptAllLanguages(suggestions, _), let .acceptAllPages(suggestions, _):
            String(localized: "Accept \(suggestions) Suggestions…")
        case .translateAll: String(localized: "Translate All…")
        case .autopilot: String(localized: "Start Autopilot…")
        case .recommendedPrices: String(localized: "Accept Suggested Prices")
        case .retention: String(localized: "Open Retention")
        case .secondApp: String(localized: "Open the App")
        case .template: String(localized: "Use the Template")
        case .eventArtwork: String(localized: "Make the Artwork…")
        case .menu: nil
        }
    }
}
