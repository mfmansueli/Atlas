//
//  StabilityAlertTextTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The Overview's crash banner: the bold lead and what follows.
@Suite("Analytics · the Overview's crash banner")
struct StabilityAlertTextTests {
    @Test func aRollingOutReleaseSaysWhoPausingProtects() {
        let text = StabilityAlertText.make(version: "1.4", previous: "1.3", times: 3.2, device: "iPhone 11", phase: .phased(day: 3, isPaused: false))
        #expect(text.lead == "Version 1.4 crashes 3.2× as often as 1.3,")
        #expect(text.detail == "mostly on iPhone 11. Pausing keeps it away from the other 95%.")
    }

    @Test func withoutADeviceTheLeadEndsTheSentence() {
        let text = StabilityAlertText.make(version: "1.4", previous: "1.3", times: 2, device: nil, phase: .phased(day: 1, isPaused: false))
        #expect(text.lead == "Version 1.4 crashes 2.0× as often as 1.3.")
        #expect(text.detail == "Pausing keeps it away from the other 99%.")
    }

    @Test func notPhasedOrPausedHasNoPausingSentence() {
        let live = StabilityAlertText.make(version: "1.4", previous: "1.3", times: 3.2, device: "iPhone 11", phase: .live)
        #expect(live.detail == "mostly on iPhone 11.")
        let paused = StabilityAlertText.make(version: "1.4", previous: "1.3", times: 3.2, device: nil, phase: .phased(day: 3, isPaused: true))
        #expect(paused.detail == nil)
    }

    @Test func pauseShowsOnlyWhileRollingOut() {
        #expect(StabilityAlertText.canPause(.phased(day: 2, isPaused: false)))
        #expect(!StabilityAlertText.canPause(.phased(day: 2, isPaused: true)))
        #expect(!StabilityAlertText.canPause(.live))
        #expect(!StabilityAlertText.canPause(nil))
        // Day 7 reaches everyone: nobody left to keep it from.
        #expect(StabilityAlertText.notYetReached(.phased(day: 7, isPaused: false)) == nil)
    }
}
