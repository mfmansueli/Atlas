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
        }
    }

    /// The counts that move into the inspector when it's open.
    var isCount: Bool { self == .impressions || self == .downloads || self == .starts }
}
