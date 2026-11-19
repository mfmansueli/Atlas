//
//  MenuBarSnapshotTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("MenuBarSnapshot and its icon state")
struct MenuBarSnapshotTests {
    private let job = BackgroundJob(id: "push", kind: .push, title: "Pushing", fraction: 0.5, detail: "")
    private let need = BackgroundNeed(id: "n", title: "Look", detail: "", destination: .reviewPush)

    @Test func workingWinsOverEverythingWhileSomethingRuns() {
        #expect(MenuBarIconState.resolve(isWorking: true, isPaused: true, hasConnectionProblem: true, needsCount: 3) == .working)
    }

    @Test func pausedThenCantConnectThenNeedsYou() {
        #expect(MenuBarIconState.resolve(isWorking: false, isPaused: true, hasConnectionProblem: true, needsCount: 3) == .paused)
        #expect(MenuBarIconState.resolve(isWorking: false, isPaused: false, hasConnectionProblem: true, needsCount: 3) == .cantConnect)
        #expect(MenuBarIconState.resolve(isWorking: false, isPaused: false, hasConnectionProblem: false, needsCount: 3) == .needsYou)
        #expect(MenuBarIconState.resolve(isWorking: false, isPaused: false, hasConnectionProblem: false, needsCount: 0) == .idle)
    }

    @Test func snapshotsResolveTheirState() {
        #expect(MenuBarSnapshot(checkLine: "").state == .idle)
        #expect(MenuBarSnapshot(jobs: [job], needs: [need], checkLine: "").state == .working)
        #expect(MenuBarSnapshot(needs: [need], checkLine: "").state == .needsYou)
        #expect(MenuBarSnapshot(checkLine: "", isPaused: true).state == .paused)
        #expect(MenuBarSnapshot(checkLine: "", connectionProblem: "401").state == .cantConnect)
    }

    @Test func quietTitleSaysWhyNothingRuns() {
        #expect(MenuBarSnapshot(checkLine: "").quietTitle == "Everything is up to date")
        #expect(MenuBarSnapshot(needs: [need], checkLine: "").quietTitle == "Nothing running")
        #expect(MenuBarSnapshot(checkLine: "", isPaused: true).quietTitle == "Background work is paused")
        #expect(MenuBarSnapshot(checkLine: "", connectionProblem: "App Store Connect rejected this key (401).").quietTitle
            == "App Store Connect rejected this key (401).")
    }

    @Test func everyStateHasAVoiceOverLabel() {
        let states: [MenuBarIconState] = [.idle, .working, .needsYou, .paused, .cantConnect]
        let labels = states.map(\.accessibilityLabel)
        #expect(Set(labels).count == states.count)
        #expect(labels.allSatisfy { $0.hasPrefix("Atlas") })
    }

    @Test func dockShowsTheIconAlwaysOrWithAWindow() {
        #expect(DockVisibility.always.showsIcon(hasOpenWindow: false))
        #expect(DockVisibility.whileWindowOpen.showsIcon(hasOpenWindow: true))
        #expect(!DockVisibility.whileWindowOpen.showsIcon(hasOpenWindow: false))
    }
}
