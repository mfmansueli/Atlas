//
//  BreakdownColumn.swift
//  Atlas
//

import Foundation

/// The breakdown table's sortable columns.
enum BreakdownColumn: String, Hashable, Sendable, CaseIterable, Identifiable, Codable {
    case name
    case impressions
    case pageViews
    case viewRate
    case downloads
    case downloadRate
    case starts
    case startRate
    case proceeds
    case trials
    /// Paid subscribers: paid starts, directly or after an offer.
    case paid
    case trialToPaid
    /// Deleted within 30 days of the download, per install (a sample).
    case deleted30
    /// Sessions a week per active device (a sample).
    case sessionsPerWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: ""
        case .impressions: String(localized: "Impressions")
        case .pageViews: String(localized: "Page views")
        case .viewRate: String(localized: "View rate")
        case .downloads: String(localized: "Downloads")
        case .downloadRate: String(localized: "Download rate")
        case .starts: String(localized: "Starts")
        case .startRate: String(localized: "Start rate")
        case .proceeds: String(localized: "Proceeds")
        case .trials: String(localized: "Trials")
        case .paid: String(localized: "Paid")
        case .trialToPaid: String(localized: "Trial → paid")
        case .deleted30: String(localized: "Deleted in 30 days")
        case .sessionsPerWeek: String(localized: "Sessions / week")
        }
    }

    /// Whether it shows in `group`; downloads show in both.
    func isShown(in group: BreakdownColumnGroup) -> Bool {
        switch self {
        case .name, .downloads: true
        case .impressions, .pageViews, .viewRate, .downloadRate, .starts, .startRate, .proceeds: group == .funnel
        case .trials, .paid, .trialToPaid, .deleted30, .sessionsPerWeek: group == .afterDownload
        }
    }

    /// The counts that move into the inspector when it's open.
    var isCount: Bool { self == .impressions || self == .downloads || self == .starts }
}
