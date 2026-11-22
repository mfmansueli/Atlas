//
//  ReportDimension.swift
//  Atlas
//

import Foundation

/// A column Atlas keeps from one of Apple's newer analytics reports, by
/// what it means. Each report names it its own way (`AppleReportKind`
/// says which), and Apple asks to read columns by name, never position.
enum ReportDimension: String, Hashable, Sendable, Codable, CaseIterable {
    case territory
    case device
    case appVersion
    /// Apple's Source Type: "App Store Search", "Web Referrer"…
    case source
    /// The app or website that sent people (Source Info), Detailed only.
    case referrer
    /// A campaign link's `ct` token, Detailed only.
    case campaign
    /// "Product page", "In-app event", "Store sheet", "No page".
    case pageType
    /// The product page's or In-App Event's name, Detailed only.
    case page
    /// "Page views", "Cancels", "Saves"; "Install", "Delete"; "Page View", "Tap".
    case event
    case subscription
    case messageType
    case messageName
    case messageID
    case offerName
    /// The plan a retention message suggests switching to.
    case suggested
    /// "Switch plan", "Redeem offer", "Don’t cancel".
    case saveType
    /// Event Grouping or State Metric Grouping, e.g. "Offer Starts".
    case grouping
    /// Event Sub Type or State Metric, e.g. "Free Trial Starts".
    case subType
    case offerType
    case offerDuration
    /// "Upgrade", "Downgrade", "Crossgrade".
    case planChange
    case cancelReason
    /// "First-time download", "Redownload", "Manual update", "Restore".
    case downloadType
    /// "1" when the app was downloaded in the 30 days before the event
    /// (Apple fills App Download Date only then), "" otherwise.
    case recentDownload
    /// What was tapped on the web preview.
    case engagementType

    /// The names Apple's files use, the first one this report has wins.
    var columnNames: [String] {
        switch self {
        case .territory: ["Territory"]
        case .device: ["Device", "Original Purchase Device"]
        case .appVersion: ["App Version"]
        case .source: ["Source Type", "App Download Source Type"]
        case .referrer: ["Source Info", "App Download Source Info"]
        case .campaign: ["Campaign"]
        case .pageType: ["Page Type"]
        case .page: ["Page Title"]
        case .event: ["Event"]
        case .subscription: ["Current Subscription", "Subscription Name"]
        case .messageType: ["Retention Message Type"]
        case .messageName: ["Retention Message Name"]
        case .messageID: ["Retention Message Identifier"]
        case .offerName: ["Offer Name"]
        case .suggested: ["Suggested Subscription"]
        case .saveType: ["Save Type"]
        case .grouping: ["Event Grouping", "State Metric Grouping"]
        case .subType: ["Event Sub Type", "State Metric"]
        case .offerType: ["Offer Type"]
        case .offerDuration: ["Offer Duration"]
        case .planChange: ["Plan Change Type"]
        case .cancelReason: ["Cancellation Reason", "Cancel Reason"]
        case .downloadType: ["Download Type"]
        case .recentDownload: ["App Download Date"]
        case .engagementType: ["Engagement Type"]
        }
    }
}
