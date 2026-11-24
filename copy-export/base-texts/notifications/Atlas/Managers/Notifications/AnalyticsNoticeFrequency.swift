//
//  AnalyticsNoticeFrequency.swift
//  Atlas
//

import Foundation

/// Settings → Notifications → "Analytics has something new".
enum AnalyticsNoticeFrequency: String, CaseIterable, Identifiable, Sendable {
    case never
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: String(localized: "Never")
        case .weekly: String(localized: "Once a week")
        }
    }

    static let week: TimeInterval = 7 * 86400
}
