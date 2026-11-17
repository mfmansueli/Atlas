//
//  AnalyticsArea.swift
//  Atlas
//

import Foundation

/// The part of Atlas a finding or a change belongs to.
enum AnalyticsArea: String, Hashable, Sendable, Codable, CaseIterable {
    case storePage
    case screenshots
    case pricing
    case retention
    /// The paywall's text, in Store Page → In-App Texts.
    case inAppTexts

    var title: String {
        switch self {
        case .storePage: String(localized: "Store Page")
        case .screenshots: String(localized: "Screenshots")
        case .pricing: String(localized: "Pricing")
        case .retention: String(localized: "Retention")
        case .inAppTexts: String(localized: "In-App Texts")
        }
    }

    var section: AppWorkspaceSection {
        switch self {
        case .storePage, .inAppTexts: .storePage
        case .screenshots: .screenshots
        case .pricing, .retention: .subscriptionPricing
        }
    }
}
