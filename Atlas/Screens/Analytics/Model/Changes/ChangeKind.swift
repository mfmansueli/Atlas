//
//  ChangeKind.swift
//  Atlas
//

import Foundation

/// What a push from Atlas changed, which decides the step it's
/// measured on.
enum ChangeKind: String, Hashable, Sendable, Codable {
    /// Name, subtitle or keywords: what search shows and matches.
    case searchText
    /// Description, promotional text, What's New: read on the page.
    case pageText
    case screenshots
    /// Prices have their own results in Pricing → Results.
    case prices
    /// The paywall's text.
    case inAppTexts

    var area: AnalyticsArea {
        switch self {
        case .searchText, .pageText: .storePage
        case .screenshots: .screenshots
        case .prices: .pricing
        case .inAppTexts: .inAppTexts
        }
    }

    /// The step the change should move; nil for prices.
    var stage: FunnelStage? {
        switch self {
        case .searchText, .screenshots: .pageViews
        case .pageText: .downloads
        case .inAppTexts: .trials
        case .prices: nil
        }
    }

    /// Search text is measured on search's impressions only.
    var source: String? {
        self == .searchText ? "App Store Search" : nil
    }

    /// The other steps, checked so a change that helped one didn't hurt them.
    var otherStages: [FunnelStage] {
        switch self {
        case .searchText, .screenshots: [.downloads, .trials]
        case .pageText: [.trials]
        case .inAppTexts: [.paid]
        case .prices: []
        }
    }
}
