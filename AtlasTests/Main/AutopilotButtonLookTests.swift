//
//  AutopilotButtonLookTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What the toolbar's Autopilot button draws while it works (board 57,
/// “While it works”): it moves only while something runs, draws a bar only
/// for counted progress, shows the check once a run ends by itself, and
/// stays still when it needs the person or something stopped.
@MainActor
@Suite("AutopilotButtonLook")
struct AutopilotButtonLookTests {
    private func progress(_ fraction: Double, counted: Bool = true) -> GuidedRunProgress {
        GuidedRunProgress(title: "Capturing in Simulator", fraction: fraction, line: "", isCounted: counted)
    }

    /// The review screenshot run counts its products but leaves the light
    /// to the card being captured: one working light on screen.
    @Test func aReviewScreenshotRunCountsWithoutTheLight() {
        let look = AutopilotButtonLook(state: .capturing("Capturing Annual · 2 of 3", progress: 1.4), done: nil, runProgress: nil)
        #expect(look == .counting("Capturing Annual · 2 of 3", progress: 1))
        #expect(!look.isWorking)
        #expect(look.progress == 1)
        #expect(look.text == "Capturing Annual · 2 of 3")
    }

    @Test func idleIsStill() {
        let look = AutopilotButtonLook(state: .idle, done: nil, runProgress: nil)
        #expect(look == .idle)
        #expect(!look.isWorking)
        #expect(look.progress == nil)
    }

    @Test func aRequestWorksWithoutABar() {
        let look = AutopilotButtonLook(state: .running("Working · Store Page · German"), done: nil, runProgress: progress(0.5))
        #expect(look == .working("Working · Store Page · German", progress: nil), "Only the guided run counts its steps")
        #expect(look.isWorking)
        #expect(look.spokenProgress == nil)
    }

    @Test func theGuidedRunsCountedProgressFillsTheBar() {
        let state = WorkspaceAutopilotState.running("Making screenshots · 5 of 10 captures", isScreenshotRun: true)
        let look = AutopilotButtonLook(state: state, done: nil, runProgress: progress(0.55))
        #expect(look.progress == 0.55)
        #expect(look.spokenProgress == "55 percent")
    }

    @Test func neverAMadeUpPercentage() {
        let state = WorkspaceAutopilotState.running("Starting Claude Code", isScreenshotRun: true)
        let look = AutopilotButtonLook(state: state, done: nil, runProgress: progress(0.02, counted: false))
        #expect(look == .working("Starting Claude Code", progress: nil))
    }

    @Test func doneShowsWhileTheCheckStays() {
        let look = AutopilotButtonLook(state: .idle, done: "Done · Store Page · German", runProgress: nil)
        #expect(look == .done("Done · Store Page · German"))
        #expect(!look.isWorking)
        #expect(AutopilotButtonLook.doneDuration == .seconds(2))
    }

    @Test func needingYouAndFailingAreStill() {
        #expect(!AutopilotButtonLook(state: .needsYou("Choose the Look"), done: "Done", runProgress: nil).isWorking)
        let failed = AutopilotButtonLook(state: .failed("Claude Code couldn’t reach Atlas"), done: nil, runProgress: nil)
        #expect(failed == .failed("Claude Code couldn’t reach Atlas"))
        #expect(!failed.isWorking)
    }

    @Test func aRunThatEndsByItselfIsDone() {
        let working = WorkspaceAutopilotState.running("Working · Store Page · German")
        #expect(working.doneText(becoming: .idle) == "Done · Store Page · German")
        #expect(WorkspaceAutopilotState.running("Claude Code is working").doneText(becoming: .idle) == "Done")
        #expect(working.doneText(becoming: .autoReplyOn("Auto-reply on")) == "Done · Store Page · German")
    }

    @Test func aRunThatStopsOrNeedsYouIsntDone() {
        let working = WorkspaceAutopilotState.running("Working · Store Page")
        #expect(working.doneText(becoming: .failed("Claude Code ended early")) == nil)
        #expect(working.doneText(becoming: .needsYou("Choose the Look")) == nil)
        #expect(working.doneText(becoming: .running("Working · Store Page")) == nil)
        #expect(WorkspaceAutopilotState.idle.doneText(becoming: .idle) == nil)
    }

    @Test func aFailureShowsOnlyWhenNothingRuns() {
        #expect(WorkspaceAutopilotState(.init(failure: "Claude Code ended early")) == .failed("Claude Code ended early"))
        #expect(WorkspaceAutopilotState(.init(launchedRuns: 1, failure: "Claude Code ended early")).isRunning)
        let failed = WorkspaceAutopilotState.failed("Claude Code ended early")
        #expect(failed.text == "Claude Code ended early")
        #expect(failed.announcementKey == "failed:Claude Code ended early")
    }

    @Test func theStarsTwinkleEveryCycleAndTheLightCrossesEveryPass() {
        #expect(AutopilotSparkle.twinkle(at: 0) == 0)
        #expect(abs(AutopilotSparkle.twinkle(at: AutopilotSparkle.cycle / 2) - 1) < 0.0001)
        #expect(abs(AutopilotSparkle.twinkle(at: AutopilotSparkle.cycle)) < 0.0001)
        #expect(AutopilotEdgeLight.bandCenter(at: 0) == -0.5)
        #expect(abs(AutopilotEdgeLight.bandCenter(at: AutopilotEdgeLight.pass / 2) - 0.5) < 0.0001)
        #expect(AutopilotEdgeLight.pass == 2.2)
        #expect(AutopilotSparkle.cycle == 1.5)
    }
}
