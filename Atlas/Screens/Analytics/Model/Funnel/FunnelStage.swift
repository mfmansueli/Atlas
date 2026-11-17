//
//  FunnelStage.swift
//  Atlas
//

import Foundation

/// The steps from seeing the app on the App Store to paying.
enum FunnelStage: String, Hashable, Sendable, CaseIterable, Identifiable, Codable {
    case impressions
    case pageViews
    case downloads
    case trials
    case paid

    var id: String { rawValue }

    /// The steps of an app without a subscription: the funnel ends at downloads.
    static let storePage: [FunnelStage] = [.impressions, .pageViews, .downloads]

    var title: String {
        switch self {
        case .impressions: String(localized: "Impressions")
        case .pageViews: String(localized: "Product page views")
        case .downloads: String(localized: "First-time downloads")
        case .trials: String(localized: "Trial starts")
        case .paid: String(localized: "Paid starts")
        }
    }

    /// What the count means, for the tooltip.
    var hint: String {
        switch self {
        case .impressions: String(localized: "Times the app showed in search, browse or a link preview")
        case .pageViews: String(localized: "Opened the product page")
        case .downloads: String(localized: "Not redownloads")
        case .trials: String(localized: "Free trials and other introductory offers started")
        case .paid: String(localized: "Trials that converted, and direct purchases")
        }
    }

    /// The rate from the step before, e.g. "Page views per impression".
    var rateTitle: String {
        switch self {
        case .impressions: String(localized: "Impressions per day")
        case .pageViews: String(localized: "Page views per impression")
        case .downloads: String(localized: "Downloads per page view")
        case .trials: String(localized: "Trials per download")
        case .paid: String(localized: "Paid per trial")
        }
    }

    var previous: FunnelStage? {
        switch self {
        case .impressions: nil
        case .pageViews: .impressions
        case .downloads: .pageViews
        case .trials: .downloads
        case .paid: .trials
        }
    }

    /// Whether the step comes from Sales and Trends.
    var isSales: Bool { self == .trials || self == .paid }

    /// The section where this step's rate is changed.
    var fixSection: AnalyticsArea {
        switch self {
        case .impressions, .pageViews: .screenshots
        case .downloads: .storePage
        case .trials: .inAppTexts
        case .paid: .pricing
        }
    }
}
