//
//  TrialReminderScheduler.swift
//  Atlas
//

import Foundation
import UserNotifications

/// Keeps one macOS notification waiting for the end of a free trial
/// (`TrialReminder`): set when a trial starts, moved when the App Store
/// moves it, removed when there's no trial anymore. It's about money, so it
/// doesn't wait for Settings → Notifications' switches.
@MainActor
final class TrialReminderScheduler {
    static let shared = TrialReminderScheduler()

    private let center: UNUserNotificationCenter?
    private let now: () -> Date
    /// The reminder waiting now (tests, and to skip asking twice).
    private(set) var pending: TrialReminder?

    /// No center in DEBUG scenes, in the tests' host or without a bundle.
    init(center: UNUserNotificationCenter? = AtlasNotifier.defaultCenter, now: @escaping () -> Date = { .now }) {
        self.center = center
        self.now = now
    }

    /// What the person owns changed (or was read at launch).
    func update(for status: ProStatus) {
        let reminder = TrialReminder(status: status, now: now())
        guard reminder != pending else { return }
        pending = reminder
        guard let center else { return }
        center.removePendingNotificationRequests(withIdentifiers: [TrialReminder.identifier])
        guard let reminder else { return }
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.threadIdentifier = "pro"
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: TrialReminder.identifier, content: content, trigger: trigger))
    }
}
