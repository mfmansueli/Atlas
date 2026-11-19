//
//  CheckInterval.swift
//  Atlas
//

import Foundation

/// Settings → General → "Check App Store Connect": how often Atlas looks
/// for new reviews, version status and analytics reports on its own.
/// "Every hour" is the default: how often a key may poll before Apple's
/// rate limits bite isn't checked, and 15 minutes is the most it offers.
enum CheckInterval: String, CaseIterable, Codable, Sendable {
    case every15Minutes
    case everyHour
    case every6Hours
    case onlyWhenAsked

    /// Seconds between checks; nil when Atlas checks only on Check Now.
    var seconds: TimeInterval? {
        switch self {
        case .every15Minutes: 15 * 60
        case .everyHour: 60 * 60
        case .every6Hours: 6 * 60 * 60
        case .onlyWhenAsked: nil
        }
    }

    var title: String {
        switch self {
        case .every15Minutes: String(localized: "Every 15 minutes")
        case .everyHour: String(localized: "Every hour")
        case .every6Hours: String(localized: "Every 6 hours")
        case .onlyWhenAsked: String(localized: "Only when I ask")
        }
    }
}
