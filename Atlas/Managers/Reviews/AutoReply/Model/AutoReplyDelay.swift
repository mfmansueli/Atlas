//
//  AutoReplyDelay.swift
//  Atlas
//

import Foundation

/// How long an allowed reply waits before it goes out by itself, so the
/// person can still change it or stop it (board 58).
enum AutoReplyDelay: Int, Codable, CaseIterable, Hashable, Sendable {
    case quarterHour = 15
    case hour = 60
    case threeHours = 180

    var interval: TimeInterval { TimeInterval(rawValue * 60) }

    var title: String {
        switch self {
        case .quarterHour: String(localized: "15 minutes")
        case .hour: String(localized: "1 hour")
        case .threeHours: String(localized: "3 hours")
        }
    }
}
