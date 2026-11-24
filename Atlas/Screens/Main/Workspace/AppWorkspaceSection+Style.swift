//
//  AppWorkspaceSection+Style.swift
//  Atlas
//

import SwiftUI

extension AppWorkspaceSection {
    /// The section's SF Symbol and system colour (README — Design system
    /// §13, board 72), in the sidebar, the section menu, Overview's rows and
    /// the section's own header.
    var style: SectionStyle {
        switch self {
        case .overview: .overview
        case .storePage: .storePage
        case .screenshots: .screenshots
        case .productPages: .productPages
        case .inAppEvents: .inAppEvents
        case .nominations: .nominations
        case .appInformation: .appInformation
        case .subscriptionPricing: .pricing
        case .reviews: .reviews
        case .analytics: .analytics
        }
    }

    /// The section's system colour, for the few marks drawn in it (stars,
    /// Analytics' funnel).
    var tint: Color { style.color }
}
