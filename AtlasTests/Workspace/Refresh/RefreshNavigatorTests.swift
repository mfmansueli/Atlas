//
//  RefreshNavigatorTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The window's Refresh (`WorkspaceNavigator`): it starts, a second click
/// does nothing while it runs, and it ends updated, failed or offline once
/// the app list, the version and the open section are in.
@MainActor
@Suite("Refresh · the window")
struct RefreshNavigatorTests {
    private let then = Date(timeIntervalSince1970: 1_793_000_000)
    private let now = Date(timeIntervalSince1970: 1_793_000_600)

    private func navigator(state: RefreshState = .idle) -> WorkspaceNavigator {
        let navigator = WorkspaceNavigator(section: .storePage)
        navigator.refreshState = state
        navigator.now = { [now] in now }
        return navigator
    }

    private func finishAll(_ navigator: WorkspaceNavigator, problem: RefreshProblem? = nil) {
        for part in RefreshPart.allCases {
            navigator.finishRefresh(part, problem: part == .apps ? problem : nil, refreshCount: navigator.refreshCount)
        }
    }

    @Test func itStartsTurning() {
        let navigator = navigator(state: .updated(then))
        navigator.refresh()
        #expect(navigator.refreshState == .refreshing(lastUpdated: then))
        #expect(navigator.refreshCount == 1)
        #expect(navigator.refreshRun?.waiting == Set(RefreshPart.allCases))
    }

    @Test func aSecondClickDoesNothing() {
        let navigator = navigator()
        navigator.refresh()
        navigator.refresh()
        #expect(navigator.refreshCount == 1)
        finishAll(navigator)
        navigator.refresh()
        #expect(navigator.refreshCount == 2, "once it ended, the button works again")
    }

    @Test func itEndsOnceEveryPartIsIn() {
        let navigator = navigator(state: .updated(then))
        navigator.refresh()
        navigator.finishRefresh(.apps, refreshCount: 1)
        navigator.finishRefresh(.release, refreshCount: 1)
        #expect(navigator.refreshState.isRefreshing)
        navigator.finishRefresh(.section, refreshCount: 1)
        #expect(navigator.refreshState == .updated(now))
        #expect(navigator.refreshRun == nil)
    }

    @Test func aFailureSaysWhatShowsIsFromTheLastGoodTime() {
        let navigator = navigator(state: .updated(then))
        let copy = AppleErrorCopy(summary: "Apple didn’t answer. Try again in a minute.", details: "HTTP 503")
        navigator.refresh()
        finishAll(navigator, problem: .failed(copy))
        #expect(navigator.refreshState == .failed(copy, lastUpdated: then))
        #expect(navigator.refreshState.needsStatusLine)
    }

    @Test func offlineKeepsItsTimeThroughTheNextRefresh() {
        let navigator = navigator(state: .updated(then))
        navigator.refresh()
        finishAll(navigator, problem: .offline)
        #expect(navigator.refreshState == .offline(since: then))
        navigator.refresh()
        #expect(navigator.refreshState == .refreshing(lastUpdated: then))
        finishAll(navigator, problem: .offline)
        #expect(navigator.refreshState == .offline(since: then), "still from the last good read")
    }

    @Test func anOldRefreshsPartsAreIgnored() {
        let navigator = navigator()
        navigator.refresh()
        navigator.finishRefresh(.apps, refreshCount: 0)
        #expect(navigator.refreshRun?.finished.isEmpty == true)
    }

    @Test func aPushDuringARefreshRefreshesAgainAfterIt() {
        let navigator = navigator()
        navigator.refresh()
        navigator.refreshAfterChange()
        #expect(navigator.refreshCount == 1)
        finishAll(navigator)
        #expect(navigator.refreshCount == 2, "what the push changed is read")
        #expect(navigator.refreshState.isRefreshing)
        finishAll(navigator)
        #expect(navigator.refreshState == .updated(now))
        #expect(navigator.refreshCount == 2)
    }

    @Test func aKeyThatOnlyReadsEndsViewOnly() {
        let navigator = navigator()
        navigator.readOnlyRole = { "Developer" }
        navigator.refresh()
        finishAll(navigator)
        #expect(navigator.refreshState == .readOnly(role: "Developer", lastUpdated: now))
    }

    @Test func theFirstReadSetsTheTime() {
        let navigator = navigator()
        navigator.noteFirstRead(problem: nil)
        #expect(navigator.refreshState == .updated(now))
        navigator.noteFirstRead(problem: .offline)
        #expect(navigator.refreshState == .updated(now), "only the first read")
        let offline = self.navigator()
        offline.noteFirstRead(problem: .offline)
        #expect(offline.refreshState == .offline(since: now))
    }
}
