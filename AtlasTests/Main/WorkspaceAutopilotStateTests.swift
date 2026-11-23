//
//  WorkspaceAutopilotStateTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// What the toolbar's Autopilot button says, from the runs it reads.
@Suite("WorkspaceAutopilotState")
struct WorkspaceAutopilotStateTests {
    @Test func reviewsAutoReplyLeftForYouNeedYou() {
        var inputs = WorkspaceAutopilotState.Inputs(autoReplyOn: "Auto-reply on")
        inputs.autoReplyNeeds = 2
        let state = WorkspaceAutopilotState(inputs)
        #expect(state == .needsYou("2 Reviews Need You"))
        #expect(WorkspaceAutopilotState.reviewsNeedYou(1) == "1 Review Needs You")
    }

    @Test func autoReplyOnShowsWhenNothingElseRuns() {
        let state = WorkspaceAutopilotState(.init(autoReplyOn: WorkspaceAutopilotState.autoReplyLine(isPaused: false, sentToday: 2)))
        #expect(state == .autoReplyOn("Auto-reply on · 2 sent today"))
        #expect(state.isOn)
        #expect(state.announcementKey == nil, "Being on isn't news")
        #expect(WorkspaceAutopilotState(.init(launchedRuns: 1, autoReplyOn: "Auto-reply on")).isRunning, "Work in progress comes first")
        #expect(WorkspaceAutopilotState.autoReplyLine(isPaused: false, sentToday: 0) == "Auto-reply on")
        #expect(WorkspaceAutopilotState.autoReplyLine(isPaused: true, sentToday: 3) == "Auto-reply paused")
    }

    /// Make Review Screenshots… shows its step and bar; what it stopped
    /// for, or what it made, in purple; the guided run still comes first.
    @Test func aReviewScreenshotRunCapturesOrNeedsYou() {
        var inputs = WorkspaceAutopilotState.Inputs(askSubject: "Pricing · review screenshots")
        inputs.reviewShotsWorking = "Capturing Annual · 2 of 3"
        inputs.reviewShotsProgress = 0.5
        let state = WorkspaceAutopilotState(inputs)
        #expect(state == .capturing("Capturing Annual · 2 of 3", progress: 0.5))
        #expect(state.isRunning)
        #expect(state.announcementKey == "running:Capturing Annual")
        #expect(state.doneText(becoming: .idle) == "Done")

        var stopped = WorkspaceAutopilotState.Inputs()
        stopped.reviewShotsNeeds = "Show It the Paywall"
        #expect(WorkspaceAutopilotState(stopped) == .needsYou("Show It the Paywall"))
        stopped.screenshotRunNeeds = "Choose the Look"
        #expect(WorkspaceAutopilotState(stopped) == .needsYou("Choose the Look"))
    }

    @Test func nothingRunningIsIdle() {
        let state = WorkspaceAutopilotState(.init())
        #expect(state == .idle)
        #expect(state.text == nil)
    }

    @Test func whatTheRunNeedsComesFirst() {
        var inputs = WorkspaceAutopilotState.Inputs(askSubject: "Store Page")
        inputs.screenshotRunNeeds = "Choose the Look"
        inputs.screenshotRunWorking = "Making screenshots · 5 of 10 captures"
        let state = WorkspaceAutopilotState(inputs)
        #expect(state == .needsYou("Choose the Look"))
        #expect(!state.isRunning)
    }

    @Test func theScreenshotRunSaysWhatItsDoing() {
        let inputs = WorkspaceAutopilotState.Inputs(askSubject: "Store Page", screenshotRunWorking: "Making screenshots · 5 of 10 captures")
        let state = WorkspaceAutopilotState(inputs)
        #expect(state == .running("Making screenshots · 5 of 10 captures", isScreenshotRun: true))
        #expect(state.text == "Making screenshots · 5 of 10 captures")
    }

    @Test func anAskSaysWhatItsAbout() {
        let state = WorkspaceAutopilotState(.init(askSubject: "In-App Events · Winter Reflection", isSuggestingEverything: true))
        #expect(state == .running("Working · In-App Events · Winter Reflection"))
        #expect(state.isRunning)
    }

    @Test func otherWorkRuns() {
        #expect(WorkspaceAutopilotState(.init(isSuggestingEverything: true)) == .running("Suggesting everything"))
        #expect(WorkspaceAutopilotState(.init(workingClient: "Claude Code")) == .running("Claude Code is working"))
        #expect(WorkspaceAutopilotState(.init(launchedRuns: 1)) == .running("Claude Code is working"))
    }

    /// VoiceOver hears a new phase once, not every capture's progress.
    @Test func onlyAPhaseChangeIsAnnounced() {
        let five = WorkspaceAutopilotState.running("Making screenshots · 5 of 10 captures", isScreenshotRun: true)
        let six = WorkspaceAutopilotState.running("Making screenshots · 6 of 10 captures", isScreenshotRun: true)
        #expect(five.announcementKey == six.announcementKey)
        #expect(five.announcementKey != WorkspaceAutopilotState.running("Localizing · 2 of 18 languages").announcementKey)
        #expect(WorkspaceAutopilotState.needsYou("Choose the Look").announcementKey == "needs:Choose the Look")
        #expect(WorkspaceAutopilotState.idle.announcementKey == nil)
        #expect(AutopilotToolbarButton.announcement("Making screenshots · 5 of 10 captures") == "Autopilot, Making screenshots, 5 of 10 captures")
    }

    @Test func eachTurnHasTheButtonsWords() {
        #expect(WorkspaceAutopilotState.needs(.pick) == "Pick the Captures")
        #expect(WorkspaceAutopilotState.needs(.choose) == "Choose the Look")
        #expect(WorkspaceAutopilotState.needs(.review) == "Approve All")
    }
}
