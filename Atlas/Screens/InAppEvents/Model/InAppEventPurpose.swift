//
//  InAppEventPurpose.swift
//  Atlas
//

import Foundation

/// Who an In-App Event is for; Apple uses it to decide who sees the card.
enum InAppEventPurpose: String, CaseIterable, Identifiable, Hashable, Sendable {
    case appropriateForAllUsers = "APPROPRIATE_FOR_ALL_USERS"
    case attractNewUsers = "ATTRACT_NEW_USERS"
    case keepActiveUsersInformed = "KEEP_ACTIVE_USERS_INFORMED"
    case bringBackLapsedUsers = "BRING_BACK_LAPSED_USERS"

    var id: String { rawValue }

    func title(appName: String) -> String {
        switch self {
        case .appropriateForAllUsers: String(localized: "Appropriate for everyone")
        case .attractNewUsers: String(localized: "Attract people new to \(appName)")
        case .keepActiveUsersInformed: String(localized: "Keep people who use \(appName) informed")
        case .bringBackLapsedUsers: String(localized: "Bring back people who stopped using \(appName)")
        }
    }

    /// App Store Connect's words, where the app isn't named: "Attract new
    /// users".
    var summary: String {
        switch self {
        case .appropriateForAllUsers: String(localized: "Appropriate for all users")
        case .attractNewUsers: String(localized: "Attract new users")
        case .keepActiveUsersInformed: String(localized: "Keep active users informed")
        case .bringBackLapsedUsers: String(localized: "Bring back lapsed users")
        }
    }
}
