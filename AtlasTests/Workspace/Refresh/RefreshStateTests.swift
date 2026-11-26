//
//  RefreshStateTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Refresh · the window's state")
struct RefreshStateTests {
    private let then = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func startingKeepsTheLastGoodTime() {
        #expect(RefreshState.idle.starting == .refreshing(lastUpdated: nil))
        #expect(RefreshState.updated(then).starting == .refreshing(lastUpdated: then))
        let error = AppleErrorCopy(summary: "Couldn’t update.", details: "HTTP 503")
        #expect(RefreshState.failed(error, lastUpdated: then).starting == .refreshing(lastUpdated: then))
    }

    @Test func onlyRefreshingTurns() {
        #expect(RefreshState.refreshing(lastUpdated: then).isRefreshing)
        #expect(!RefreshState.updated(then).isRefreshing)
        #expect(!RefreshState.idle.isRefreshing)
    }

    @Test func theStatusLineSpeaksOnlyWhenSomethingIsWrong() {
        let error = AppleErrorCopy(summary: "Couldn’t update.", details: nil)
        #expect(RefreshState.failed(error, lastUpdated: then).needsStatusLine)
        #expect(RefreshState.offline(since: then).needsStatusLine)
        #expect(RefreshState.readOnly(role: "Developer", lastUpdated: then).needsStatusLine)
        #expect(!RefreshState.updated(then).needsStatusLine)
        #expect(!RefreshState.refreshing(lastUpdated: then).needsStatusLine)
        #expect(!RefreshState.idle.needsStatusLine)
    }

    @Test func lastUpdatedComesFromTheState() {
        #expect(RefreshState.updated(then).lastUpdated == then)
        #expect(RefreshState.readOnly(role: "Developer", lastUpdated: then).lastUpdated == then)
        #expect(RefreshState.offline(since: then).lastUpdated == nil)
    }
}
