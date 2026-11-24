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
    private(set) var sent: [Sent] = []

    /// One notification as it was sent.
    struct Sent {
        let kind: Kind
        let title: String
        let body: String
        let category: AtlasNotificationCategory?
    }

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

    /// `category` adds its buttons; `userInfo` says which app and review
    /// they act on.
    func post(
        _ kind: Kind, title: String, body: String, identifier: String, category: AtlasNotificationCategory? = nil,
        userInfo: [String: String] = [:]
    ) {
        guard allows(kind) else { return }
        sent.append(Sent(kind: kind, title: title, body: body, category: category))
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.threadIdentifier = identifier.components(separatedBy: ".").first ?? identifier
        if let category { content.categoryIdentifier = category.rawValue }
        content.userInfo = userInfo
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    /// The buttons Atlas's notifications can have, and who answers them;
    /// once, at launch.
    func register(_ responder: AtlasNotificationResponder) {
        guard let center else { return }
        center.setNotificationCategories(AtlasNotificationCategory.all)
        center.delegate = responder
    }

    /// What macOS allows, for the top of Settings → Notifications.
    func permission() async -> NotificationPermission {
        guard let center else { return .allowed }
        return await NotificationPermission(center.notificationSettings().authorizationStatus)
    }
}
