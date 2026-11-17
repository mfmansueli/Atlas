//
//  AnalyticsRefreshMode.swift
//  Atlas
//

import Foundation

/// When Atlas downloads Apple's reports.
enum AnalyticsRefreshMode: String, Hashable, Sendable, Codable, CaseIterable, Identifiable {
    /// Once a day while Atlas is open, and when it opens.
    case everyMorning
    /// Only when the Analytics section is opened.
    case whenOpened

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyMorning: String(localized: "Every morning")
        case .whenOpened: String(localized: "When I open Analytics")
        }
    }
}
