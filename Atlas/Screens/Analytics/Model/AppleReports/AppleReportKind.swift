//
//  AppleReportKind.swift
//  Atlas
//

import Foundation

/// The Analytics Reports API's reports Atlas reads after the store page:
/// what happens on the cancel screen, subscribers by page and campaign,
/// crashes, deletions, sessions, the web preview and widgets. They come
/// with the same report request as the funnel's two (`EngagementReportKind`).
enum AppleReportKind: String, Hashable, Sendable, Codable, CaseIterable, Identifiable {
    case retention
    case subscriptionEvents
    case subscriptionStates
    case crashes
    case installs
    case sessions
    case webPreview
    case widgets

    var id: String { rawValue }

    /// Apple's name for it, without the Standard or Detailed suffix.
    var title: String {
        switch self {
        case .retention: String(localized: "Retention Messaging", comment: "kind:section-title")
        case .subscriptionEvents: String(localized: "App Store Subscription Event", comment: "kind:section-title")
        case .subscriptionStates: String(localized: "App Store Subscription State", comment: "kind:section-title")
        case .crashes: String(localized: "App Crashes", comment: "kind:section-title")
        case .installs: String(localized: "App Store Installations and Deletions", comment: "kind:section-title")
        case .sessions: String(localized: "App Sessions", comment: "kind:section-title")
        case .webPreview: String(localized: "App Store Web Preview", comment: "kind:section-title")
        case .widgets: String(localized: "Home Screen Widget Installs", comment: "kind:section-title")
        }
    }

    /// What it adds, in a few words.
    var adds: String {
        switch self {
        case .retention: String(localized: "Cancel-screen views, cancels and saves, by message")
        case .subscriptionEvents: String(localized: "Trials, paid starts, offers and plan changes, by page")
        case .subscriptionStates: String(localized: "Active, billing retry, grace period, by page and campaign")
        case .crashes: String(localized: "Crashes by version and device")
        case .installs: String(localized: "Installs and deletions by version, source and page")
        case .sessions: String(localized: "Sessions, duration and active devices")
        case .webPreview: String(localized: "apps.apple.com page views and taps")
        case .widgets: String(localized: "Devices that added a widget")
        }
    }

    /// Whether it only counts people who share analytics with developers.
    var isSample: Bool {
        switch self {
        case .crashes, .installs, .sessions, .widgets: true
        case .retention, .subscriptionEvents, .subscriptionStates, .webPreview: false
        }
    }

    /// Days Apple takes to complete a day; the newest ones are left out
    /// where they'd change a rate (Retention Messaging).
    var completeAfterDays: Int {
        switch self {
        case .retention: 4
        case .crashes, .installs, .sessions: 5
        case .subscriptionEvents, .subscriptionStates, .webPreview: 3
        case .widgets: 8
        }
    }

    /// The date column; the subscription event report names it otherwise.
    var dateColumns: [String] { ["Date", "Event Date"] }

    /// What's kept of each row, the rest added up.
    var dimensions: [ReportDimension] {
        switch self {
        case .retention:
            [.event, .subscription, .messageType, .messageName, .messageID, .offerName, .suggested, .saveType, .device, .territory]
        case .subscriptionEvents:
            [
                .grouping, .subType, .subscription, .offerType, .offerName, .offerDuration, .planChange, .cancelReason, .source,
                .referrer, .campaign, .pageType, .page, .device, .territory,
            ]
        case .subscriptionStates:
            [.grouping, .subType, .subscription, .offerName, .source, .campaign, .pageType, .page, .territory]
        case .crashes:
            [.appVersion, .device]
        case .installs:
            [.event, .downloadType, .appVersion, .device, .source, .referrer, .campaign, .pageType, .page, .recentDownload, .territory]
        case .sessions:
            [.appVersion, .device, .source, .referrer, .campaign, .pageType, .page, .territory]
        case .webPreview:
            [.event, .engagementType, .pageType, .page, .source]
        case .widgets:
            [.device, .territory]
        }
    }

    var measures: [ReportMeasure] {
        switch self {
        case .retention, .subscriptionEvents, .subscriptionStates, .webPreview: [.counts]
        case .crashes: [.crashes, .uniqueDevices]
        case .installs, .widgets: [.counts, .uniqueDevices]
        case .sessions: [.sessions, .duration, .uniqueDevices]
        }
    }

    /// Whether a report's name is this one's. The API adds a Standard or
    /// Detailed suffix; names are matched by what they say, and the
    /// expanded or context variants of crashes and sessions are others.
    func matches(reportName: String) -> Bool {
        let name = reportName.lowercased()
        switch self {
        case .retention: return name.contains("retention messaging")
        case .subscriptionEvents: return name.contains("subscription event")
        case .subscriptionStates: return name.contains("subscription state")
        case .crashes: return name.hasPrefix("app crashes") && !name.contains("expanded")
        case .installs: return name.contains("installation") && name.contains("deletion")
        case .sessions: return name.hasPrefix("app sessions") && !name.contains("context")
        case .webPreview: return name.contains("web preview")
        case .widgets: return name.contains("home screen widget install")
        }
    }

    /// The kind a report's name is, if any.
    static func kind(reportName: String) -> AppleReportKind? {
        allCases.first { $0.matches(reportName: reportName) }
    }
}
