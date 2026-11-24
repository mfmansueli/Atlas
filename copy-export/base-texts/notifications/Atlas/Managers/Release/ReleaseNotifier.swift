//
//  ReleaseNotifier.swift
//  Atlas
//

import Foundation
import UserNotifications

/// Tells the person when App Review moved their version while they were
/// doing something else: a macOS notification, asked for the first time
/// they submit.
@MainActor
final class ReleaseNotifier {
    static let shared = ReleaseNotifier()

    private let center: UNUserNotificationCenter?

    /// No center without a bundle (unit tests of the model), in DEBUG
    /// scenes or in the test host.
    init(center: UNUserNotificationCenter? = ReleaseNotifier.defaultCenter) {
        self.center = center
    }

    private static var defaultCenter: UNUserNotificationCenter? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(_ text: String, appName: String, appID: StoreApp.ID) {
        // Settings → Notifications → "App Review changes a version's or an
        // event's status".
        guard let center, NotificationPreferences.shared.reviewStatus else { return }
        let content = UNMutableNotificationContent()
        content.title = appName
        content.body = text
        content.sound = AtlasNotifier.shared.sound
        content.threadIdentifier = "release"
        center.add(UNNotificationRequest(identifier: "release.\(appID)", content: content, trigger: nil))
    }
}
