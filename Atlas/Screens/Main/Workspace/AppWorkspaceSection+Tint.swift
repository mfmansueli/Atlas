//
//  AppWorkspaceSection+Tint.swift
//  Atlas
//

import SwiftUI

extension AppWorkspaceSection {
    /// The section's flat colour, for marks drawn in it.
    var tint: Color {
        switch self {
        case .overview: Palette.sectionOverview
        case .storePage: Palette.sectionStorePage
        case .screenshots: Palette.sectionScreenshots
        case .productPages: Palette.sectionProductPages
        case .inAppEvents: Palette.sectionEvents
        case .appInformation: Palette.sectionAppInformation
        case .subscriptionPricing: Palette.sectionPricing
        case .reviews: Palette.sectionReviews
        case .analytics: Palette.sectionAnalytics
        }
    }

    /// The upper colour of the tile's gradient.
    var tintTop: Color {
        switch self {
        case .overview: Palette.sectionOverviewTop
        case .storePage: Palette.sectionStorePageTop
        case .screenshots: Palette.sectionScreenshotsTop
        case .productPages: Palette.sectionProductPagesTop
        case .inAppEvents: Palette.sectionEventsTop
        case .appInformation: Palette.sectionAppInformationTop
        case .subscriptionPricing: Palette.sectionPricingTop
        case .reviews: Palette.sectionReviewsTop
        case .analytics: Palette.sectionAnalyticsTop
        }
    }

    /// The tile's fill, in the sidebar, the section menu and the Overview's
    /// rows: top lighter, as System Settings draws its own.
    var tileGradient: LinearGradient {
        LinearGradient(colors: [tintTop, tint], startPoint: .top, endPoint: .bottom)
    }
}
