//
//  AppWorkspaceSection+Help.swift
//  Atlas
//

import Foundation

extension AppWorkspaceSection {
    /// The Help article the ? beside the section's title opens.
    var helpArticleID: String {
        switch self {
        case .overview: "what"
        case .storePage: "store"
        case .screenshots: "shots"
        case .productPages: "pages"
        case .inAppEvents: "events"
        case .nominations: "nominations"
        case .appInformation: "info"
        case .subscriptionPricing: "pricing"
        case .reviews: "reviews"
        case .analytics: "analytics"
        }
    }
}
