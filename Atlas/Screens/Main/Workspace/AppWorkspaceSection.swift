//
//  AppWorkspaceSection.swift
//  Atlas
//

import Foundation

/// The nine sections of an app's workspace, picked in the sidebar
/// (⌘1–⌘9), in the sidebar's order: Overview, then the Store Listing's
/// sections, then what happens after release.
enum AppWorkspaceSection: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Summary cards and quick actions.
    case overview
    /// The App Store listing's text in every locale.
    case storePage
    /// The App Store preview, Autopilot, and the sets, template, captions
    /// and captures behind them.
    case screenshots
    /// Custom product pages: a page of its own for each audience, with its
    /// own link, texts, keywords and screenshots, beside the default page.
    case productPages
    /// The cards on the App Store for what's happening in the app.
    case inAppEvents
    /// Categories, age rating, App Privacy, App Review and export compliance.
    case appInformation
    /// Per-territory prices for subscriptions and in-app purchases.
    case subscriptionPricing
    /// What people write on the App Store, in every country, and the replies.
    case reviews
    /// The funnel from impression to paid subscriber, and what to change next.
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: String(localized: "Overview")
        case .storePage: String(localized: "Store Page")
        case .screenshots: String(localized: "Screenshots")
        case .productPages: String(localized: "Custom Product Pages")
        case .inAppEvents: String(localized: "In-App Events")
        case .appInformation: String(localized: "App Information")
        case .subscriptionPricing: String(localized: "Pricing")
        case .reviews: String(localized: "Reviews")
        case .analytics: String(localized: "Analytics")
        }
    }

    /// The unshortened name, for the View menu and push history:
    /// "Subscription Pricing · Mexico, Türkiye, India".
    var fullTitle: String {
        switch self {
        case .subscriptionPricing: String(localized: "Subscription Pricing")
        case .reviews: String(localized: "Ratings & Reviews")
        default: title
        }
    }

    /// The glyph on the section's tile, in the sidebar and its own header.
    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .storePage: "doc.text.fill"
        case .screenshots: "iphone"
        case .productPages: "doc.on.doc.fill"
        case .inAppEvents: "calendar"
        case .appInformation: "info.circle.fill"
        case .subscriptionPricing: "tag.fill"
        case .reviews: "star.fill"
        case .analytics: "chart.bar.fill"
        }
    }

    /// The digit for ⌘1–⌘9, in the sidebar's order: Product Pages took ⌘4
    /// and moved the four after it by one.
    var shortcutDigit: Character {
        switch self {
        case .overview: "1"
        case .storePage: "2"
        case .screenshots: "3"
        case .productPages: "4"
        case .inAppEvents: "5"
        case .appInformation: "6"
        case .subscriptionPricing: "7"
        case .reviews: "8"
        case .analytics: "9"
        }
    }

    /// Where the sidebar lists it.
    var group: AppWorkspaceSectionGroup {
        switch self {
        case .overview: .overview
        case .storePage, .screenshots, .productPages, .inAppEvents, .appInformation, .subscriptionPricing: .storeListing
        case .reviews, .analytics: .afterRelease
        }
    }
}
