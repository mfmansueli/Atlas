//
//  AtlasNotificationResponderTests.swift
//  AtlasTests
//

import Testing
import UserNotifications
@testable import Atlas

/// The buttons on Reply Automatically's notifications (board 58): a
/// drafted reply has Send Reply and Open Reviews, one that waits only Open
/// Reviews; clicking opens the app's Reviews, and Send Reply falls back to
/// it when the window that sends isn't there.
@MainActor
@Suite("AtlasNotificationResponder")
struct AtlasNotificationResponderTests {
    private let info: [AnyHashable: Any] = ["appID": "app", "reviewID": "r1"]

    @Test func eachKindHasItsButtons() {
        #expect(AtlasNotificationCategory.autoReplyReady.actions.map(\.identifier) == ["autoreply.send", "autoreply.open"])
        #expect(AtlasNotificationCategory.autoReplyNeedsYou.actions.map(\.identifier) == ["autoreply.open"])
        #expect(AtlasNotificationCategory.all.count == 2)
    }

    @Test func clicksAndButtonsAreRead() {
        #expect(AtlasNotificationResponder.response(action: UNNotificationDefaultActionIdentifier, userInfo: info) == .openReviews(appID: "app"))
        #expect(AtlasNotificationResponder.response(action: "autoreply.open", userInfo: info) == .openReviews(appID: "app"))
        #expect(AtlasNotificationResponder.response(action: "autoreply.send", userInfo: info) == .sendReply(appID: "app", reviewID: "r1"))
        #expect(AtlasNotificationResponder.response(action: UNNotificationDismissActionIdentifier, userInfo: info) == nil)
        #expect(AtlasNotificationResponder.response(action: UNNotificationDefaultActionIdentifier, userInfo: [:]) == nil, "Other notifications")
    }

    @Test func sendReplyOpensReviewsWhenItCantSend() async {
        let responder = AtlasNotificationResponder()
        var opened: [BackgroundDestination] = []
        responder.open = { opened.append($0) }
        responder.sendReply = { _, _ in false }
        await responder.handle(.sendReply(appID: "app", reviewID: "r1"))
        #expect(opened == [.section(.reviews, appID: "app")])

        opened = []
        var sent: [String] = []
        responder.sendReply = { _, reviewID in sent.append(reviewID); return true }
        await responder.handle(.sendReply(appID: "app", reviewID: "r1"))
        #expect(sent == ["r1"])
        #expect(opened.isEmpty)
    }
}
