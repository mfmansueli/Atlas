//
//  BreakdownDimension.swift
//  Atlas
//

import Foundation

/// What Break It Down splits the funnel by.
enum BreakdownDimension: String, Hashable, Sendable, CaseIterable, Identifiable, Codable {
    case territory
    case language
    case source
    case device
    case productPage
    /// The app or website that sent people (Apple's Source Info).
    case referrer
    /// An App Analytics campaign link's token.
    case campaign

    var id: String { rawValue }

    var title: String {
        switch self {
        case .territory: String(localized: "Territory")
        case .language: String(localized: "Language")
        case .source: String(localized: "Source")
        case .device: String(localized: "Device")
        case .productPage: String(localized: "Product Page")
        case .referrer: String(localized: "Referrer")
        case .campaign: String(localized: "Campaign")
        }
    }

    /// What the table says when no row came back: Apple leaves out rows
    /// with fewer than five people, so a small app's referrers and
    /// campaigns are often all gone.
    var emptyText: String {
        switch self {
        case .referrer:
            String(localized: "No app or website sent five or more people in this period, so Apple left them all out.")
        case .campaign:
            String(localized: """
            No campaign link brought five or more people in this period. Make links in App Store Connect → App Analytics → \
            Campaigns, and add their ct token where you share the app.
            """)
        case .productPage:
            String(localized: "No product page had five or more people in this period, so Apple left them all out.")
        case .territory, .language, .source, .device:
            String(localized: "Nothing to split yet: Apple left out every row with fewer than five people in this period.")
        }
    }

    /// Whether Apple links sales to this split.
    var hasSales: Bool {
        switch self {
        case .territory, .language, .device: true
        case .source, .productPage, .referrer, .campaign: false
        }
    }
}
