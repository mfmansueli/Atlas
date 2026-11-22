//
//  AtlasNotificationResponder.swift
//  Atlas
//

import Foundation
import UserNotifications

/// What a click on one of Atlas's notifications does (board 58): a
/// review's notification opens the app's Reviews, and Send Reply sends the
/// drafted reply shown in it, as the person's own Send Reply. Others only
/// bring Atlas forward, as before.
@MainActor
final class AtlasNotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    enum Response: Equatable, Sendable {
        case openReviews(appID: StoreApp.ID)
        case sendReply(appID: StoreApp.ID, reviewID: AppReview.ID)
    }

    /// Opens a place in the main window.
    var open: (BackgroundDestination) -> Void = { _ in }
    /// Sends the review's drafted reply; false when the window that can
    /// send isn't there, so Reviews opens instead.
    var sendReply: (StoreApp.ID, AppReview.ID) async -> Bool = { _, _ in false }

    /// The response for a button (or a click, the default action) and the
    /// notification's userInfo; nil for a notification without one.
    nonisolated static func response(action: String, userInfo: [AnyHashable: Any]) -> Response? {
        guard let appID = userInfo[AtlasNotificationCategory.appIDKey] as? String else { return nil }
        if action == AtlasNotificationCategory.sendReply, let reviewID = userInfo[AtlasNotificationCategory.reviewIDKey] as? String {
            return .sendReply(appID: appID, reviewID: reviewID)
        }
        guard action == AtlasNotificationCategory.openReviews || action == UNNotificationDefaultActionIdentifier else { return nil }
        return .openReviews(appID: appID)
    }

    nonisolated func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        guard let reply = Self.response(action: action, userInfo: userInfo) else { return }
        await handle(reply)
    }

    func handle(_ response: Response) async {
        switch response {
        case let .openReviews(appID):
            open(.section(.reviews, appID: appID))
        case let .sendReply(appID, reviewID):
            if await !sendReply(appID, reviewID) { open(.section(.reviews, appID: appID)) }
        }
    }
}
