//
//  AppWorkspaceSection+Tint.swift
//  Atlas
//

import SwiftUI

extension AppWorkspaceSection {
    /// The color of the section's tile, in the sidebar, the section menu
    /// and the Overview's rows.
    var tint: Color {
        switch self {
        case .overview: Palette.sectionOverview
        case .storePage: Palette.sectionStorePage
        case .screenshots: Palette.sectionScreenshots
        case .inAppEvents: Palette.sectionEvents
        case .appInformation: Palette.sectionAppInformation
        case .subscriptionPricing: Palette.sectionPricing
        case .reviews: Palette.sectionReviews
        case .analytics: Palette.sectionAnalytics
        }
    }
}
