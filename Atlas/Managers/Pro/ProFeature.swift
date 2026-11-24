//
//  ProFeature.swift
//  Atlas
//

import Foundation

/// What Atlas Pro adds. Free does it one at a time; Pro does it all
/// at once, plus the tools that earn the developer money and more than one
/// app. Reading, editing, pushing and anything a person already made are
/// never one of these.
enum ProFeature: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// Accept All Languages, Accept All Pages, Translate All.
    case acceptAll
    /// Screenshot Autopilot: screenshots, App Preview and header artwork.
    case autopilot
    /// Suggested prices for every country.
    case recommendedPrices
    /// Retention messages and offers.
    case retention
    /// More than one app or App Store Connect account.
    case multipleApps
    /// Every screenshot template and device.
    case allTemplates

    var id: String { rawValue }

    /// The paywall's list, in this order.
    var title: String {
        switch self {
        case .acceptAll: String(localized: "Everything at once")
        case .autopilot: String(localized: "Autopilot")
        case .recommendedPrices: String(localized: "Prices for 175 countries")
        case .retention: String(localized: "Retention")
        case .multipleApps: String(localized: "Every app and team")
        case .allTemplates: String(localized: "All 14 templates, every device")
        }
    }

    var detail: String {
        switch self {
        case .acceptAll: String(localized: "Accept All Languages, Translate All and every App Information page in one step.")
        case .autopilot: String(localized: "Screenshots, App Preview and header artwork in every language, made for you.")
        case .recommendedPrices: String(localized: "Suggested prices for local purchasing power, checked per country.")
        case .retention: String(localized: "Messages and offers when someone taps Cancel Subscription.")
        case .multipleApps: String(localized: "All your apps and App Store Connect accounts in one window.")
        case .allTemplates: String(localized: "Mac, iPad, iPhone Duo, Vision Pro and Apple Watch.")
        }
    }

    /// The paywall's symbols (README-DS §13, the paywall's board).
    var systemImage: String {
        switch self {
        case .acceptAll: "sparkles"
        case .autopilot: "wand.and.sparkles"
        case .recommendedPrices: "tag"
        case .retention: "arrow.uturn.backward"
        case .multipleApps: "square.grid.2x2"
        case .allTemplates: "macbook.and.iphone"
        }
    }
}
