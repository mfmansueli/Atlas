//
//  SettingsPane+Tile.swift
//  Atlas
//

import SwiftUI

extension SettingsPane {
    /// The pane's tile, in the section palette (README — Design system §2):
    /// AI Assistants is the one purple tile, because it is the AI;
    /// Suggestions takes indigo beside it; Atlas Pro the brand's blue.
    var tileGradient: LinearGradient {
        switch self {
        case .general: Self.gradient(Palette.sectionAppInformationTop, Palette.sectionAppInformation)
        case .accounts: Self.gradient(Palette.sectionStorePageTop, Palette.sectionStorePage)
        case .assistants: Self.gradient(Palette.aiFill, Palette.ai)
        case .suggestions: Self.gradient(Palette.sectionAnalyticsTop, Palette.sectionAnalytics)
        case .pricing: Self.gradient(Palette.sectionPricingTop, Palette.sectionPricing)
        case .screenshots: Self.gradient(Palette.sectionScreenshotsTop, Palette.sectionScreenshots)
        case .notifications: Self.gradient(Palette.errMark, Palette.err)
        case .pro: PaywallStyle.brightGradient
        case .privacy: Self.gradient(Palette.sectionOverviewTop, Palette.sectionOverview)
        }
    }

    private static func gradient(_ top: Color, _ bottom: Color) -> LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}
