//
//  NotificationPreferences.swift
//  Atlas
//

import Foundation
import Observation

/// Settings → Notifications (board 48): what Atlas tells you about while
/// you're doing something else, and how (a sound, the menu bar icon's dot,
/// the count on the Dock icon). Kept in `UserDefaults`; in memory for
/// DEBUG scenes and the tests' host.
@MainActor
@Observable
final class NotificationPreferences {
    static let shared = NotificationPreferences(defaults: NotificationPreferences.defaultStore)

    /// Autopilot or Claude waits for a choice.
    var needsYou: Bool { didSet { save(needsYou, Key.needsYou) } }
    /// App Review moved a version or an event.
    var reviewStatus: Bool { didSet { save(reviewStatus, Key.reviewStatus) } }
    /// A push finished. One that fails always tells.
    var pushFinished: Bool { didSet { save(pushFinished, Key.pushFinished) } }
    var newReviews: ReviewNoticeLevel { didSet { save(newReviews.rawValue, Key.newReviews) } }
    var analytics: AnalyticsNoticeFrequency { didSet { save(analytics.rawValue, Key.analytics) } }
    var playsSound: Bool { didSet { save(playsSound, Key.playsSound) } }
    var showsMenuBarDot: Bool { didSet { save(showsMenuBarDot, Key.showsMenuBarDot) } }
    /// What needs you, not what's suggested.
    var showsDockCount: Bool { didSet { save(showsDockCount, Key.showsDockCount) } }
    /// When Analytics last told about new findings.
    var lastAnalyticsNotice: Date? { didSet { defaults?.set(lastAnalyticsNotice, forKey: Key.lastAnalyticsNotice) } }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        needsYou = defaults?.object(forKey: Key.needsYou) as? Bool ?? true
        reviewStatus = defaults?.object(forKey: Key.reviewStatus) as? Bool ?? true
        pushFinished = defaults?.object(forKey: Key.pushFinished) as? Bool ?? true
        newReviews = defaults?.string(forKey: Key.newReviews).flatMap(ReviewNoticeLevel.init(rawValue:)) ?? .lowRatings
        analytics = defaults?.string(forKey: Key.analytics).flatMap(AnalyticsNoticeFrequency.init(rawValue:)) ?? .weekly
        playsSound = defaults?.bool(forKey: Key.playsSound) ?? false
        showsMenuBarDot = defaults?.object(forKey: Key.showsMenuBarDot) as? Bool ?? true
        showsDockCount = defaults?.object(forKey: Key.showsDockCount) as? Bool ?? true
        lastAnalyticsNotice = defaults?.object(forKey: Key.lastAnalyticsNotice) as? Date
    }

    /// Whether the weekly Analytics notice is due.
    func analyticsNoticeIsDue(now: Date) -> Bool {
        guard analytics == .weekly else { return false }
        guard let lastAnalyticsNotice else { return true }
        return now.timeIntervalSince(lastAnalyticsNotice) >= AnalyticsNoticeFrequency.week
    }

    private func save(_ value: Any, _ key: String) {
        defaults?.set(value, forKey: key)
    }

    private static var defaultStore: UserDefaults? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return .standard
    }

    private enum Key {
        static let needsYou = "notifications.needsYou"
        static let reviewStatus = "notifications.reviewStatus"
        static let pushFinished = "notifications.pushFinished"
        static let newReviews = "notifications.newReviews"
        static let analytics = "notifications.analytics"
        static let playsSound = "notifications.playsSound"
        static let showsMenuBarDot = "notifications.showsMenuBarDot"
        static let showsDockCount = "notifications.showsDockCount"
        static let lastAnalyticsNotice = "notifications.lastAnalyticsNotice"
    }
}
