//
//  PushControllerConnectionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// “You’re offline” follows the Mac's connection: it shows only while the Mac
/// has no network and leaves by itself when it comes back (it used to stay
/// until the next push).
@MainActor
@Suite("PushController connection")
struct PushControllerConnectionTests {
    private let push = PushController(queue: ChangeQueue(), history: PushHistory())

    @Test func theBannerLeavesWhenTheConnectionComesBack() {
        push.connectionChanged(isOnline: false)
        _ = StorePageErrorReporter.report(URLError(.notConnectedToInternet), to: push)
        #expect(push.notice == .offline)
        push.connectionChanged(isOnline: true)
        #expect(push.notice == nil)
    }

    @Test func aTimeoutWhileOnlineIsntOffline() {
        push.connectionChanged(isOnline: true)
        _ = StorePageErrorReporter.report(URLError(.timedOut), to: push)
        _ = AppInformationErrorReporter.report(URLError(.cannotConnectToHost), to: push)
        #expect(push.notice == nil)
    }

    @Test func comingBackOnlineKeepsOtherNotices() {
        push.report(.apiError("Apple said no"))
        push.connectionChanged(isOnline: true)
        #expect(push.notice == .apiError("Apple said no"))
    }

    @Test func beforeTheConnectionIsKnownOfflineShows() {
        #expect(push.isOnline == nil)
        push.report(.offline)
        #expect(push.notice == .offline)
    }

    @Test func aPushWhileOnlineDoesntSayOffline() async {
        let queue = ChangeQueue()
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport(failures: ["BRA": URLError(.networkConnectionLost)]))
        push.connectionChanged(isOnline: true)
        queue.upsert(contentsOf: ["BRA", "MEX"].map { PushFixtures.price($0) })
        push.push(queue.changes)
        await push.waitUntilFinished()
        #expect(push.notice == nil)
    }
}
