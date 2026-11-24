//
//  NotificationPermission.swift
//  Atlas
//

import UserNotifications

/// Whether macOS lets Atlas's notifications through, read each time
/// Settings → Notifications opens.
enum NotificationPermission: Hashable, Sendable {
    case allowed
    case blocked
    /// Not asked yet: the first notification Atlas wants to send asks.
    case notAsked

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral: self = .allowed
        case .denied: self = .blocked
        case .notDetermined: self = .notAsked
        @unknown default: self = .notAsked
        }
    }

    /// System Settings → Notifications, at Atlas.
    static var settingsURL: URL? {
        let id = Bundle.main.bundleIdentifier ?? "com.lima.atlas"
        return URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")
    }
}
