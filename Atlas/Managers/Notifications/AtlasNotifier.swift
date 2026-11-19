//
//  AtlasNotifier.swift
//  Atlas
//

import Foundation
import UserNotifications

/// The macOS notifications Settings → Notifications chooses: a push that
/// finished, new reviews, Analytics' new findings, concepts ready to
/// choose. Each kind is sent only while its switch is on (a failed push
/// always is), with a sound when asked for. The first one asks macOS.
@MainActor
final class AtlasNotifier {
    static let shared = AtlasNotifier()

    enum Kind: Sendable {
        case needsYou
        case reviewStatus
        case pushFinished
        case pushFailed
        case newReviews
        case analytics
    }

    private let center: UNUserNotificationCenter?
    private let preferences: NotificationPreferences
    /// What was sent, newest last (tests).
    private(set) var sent: [(kind: Kind, title: String, body: String)] = []

    /// No center without a bundle, in DEBUG scenes or in the tests' host.
    init(center: UNUserNotificationCenter? = AtlasNotifier.defaultCenter, preferences: NotificationPreferences = .shared) {
        self.center = center
        self.preferences = preferences
    }

    static var defaultCenter: UNUserNotificationCenter? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func allows(_ kind: Kind) -> Bool {
        switch kind {
        case .needsYou: preferences.needsYou
        case .reviewStatus: preferences.reviewStatus
        case .pushFinished: preferences.pushFinished
        case .pushFailed: true
        case .newReviews: preferences.newReviews != .never
        case .analytics: preferences.analytics != .never
        }
    }

    /// The sound a notification of Atlas's plays, if any.
    var sound: UNNotificationSound? {
        preferences.playsSound ? .default : nil
    }

    func post(_ kind: Kind, title: String, body: String, identifier: String) {
        guard allows(kind) else { return }
        sent.append((kind, title, body))
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.threadIdentifier = identifier.components(separatedBy: ".").first ?? identifier
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    /// What macOS allows, for the top of Settings → Notifications.
    func permission() async -> NotificationPermission {
        guard let center else { return .allowed }
        return await NotificationPermission(center.notificationSettings().authorizationStatus)
    }
}
