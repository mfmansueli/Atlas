//
//  AtlasNotificationCategory.swift
//  Atlas
//

import Foundation
import UserNotifications

/// The notifications with buttons (board 58): a reply Reply Automatically
/// drafted (Send Reply, Open Reviews) and one it left for the person
/// (Open Reviews). Clicking either opens the app's Reviews.
enum AtlasNotificationCategory: String, CaseIterable {
    /// "A reply is ready for a 5★ review", with the reply in the body.
    case autoReplyReady = "autoreply.ready"
    /// "A 1★ review needs your reply", with why it waits.
    case autoReplyNeedsYou = "autoreply.needsYou"

    /// Button identifiers, in the response.
    static let sendReply = "autoreply.send"
    static let openReviews = "autoreply.open"
    /// userInfo keys.
    static let appIDKey = "appID"
    static let reviewIDKey = "reviewID"

    var actions: [UNNotificationAction] {
        let open = UNNotificationAction(identifier: Self.openReviews, title: String(localized: "Open Reviews"), options: [.foreground])
        switch self {
        case .autoReplyReady:
            // Public on the App Store: sent as written in the body.
            return [UNNotificationAction(identifier: Self.sendReply, title: String(localized: "Send Reply"), options: []), open]
        case .autoReplyNeedsYou:
            return [open]
        }
    }

    var category: UNNotificationCategory {
        UNNotificationCategory(identifier: rawValue, actions: actions, intentIdentifiers: [])
    }

    static var all: Set<UNNotificationCategory> { Set(allCases.map(\.category)) }
}
