//
//  AppInformationPageStatusTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// A page card's state (board 88): suggestions first in purple, then what
/// needs the person in amber, then Ready in green; a skeleton while it
/// loads.
@Suite("AppInformationPageStatus")
struct AppInformationPageStatusTests {
    @Test func suggestionsComeFirstInPurple() {
        let status = AppInformationPageStatus(isLoaded: true, suggested: 3, needsYou: 2)
        #expect(status.state == .suggested(3))
        #expect(status.text == "3 suggested")
        #expect(status.tone == .ai)
        #expect(!status.isReady)
    }

    @Test func whatNeedsThePersonIsAmber() {
        let two = AppInformationPageStatus(isLoaded: true, suggested: 0, needsYou: 2)
        #expect(two.state == .needsYou(2))
        #expect(two.text == "2 need you")
        #expect(two.tone == .warning)
        #expect(AppInformationPageStatus(isLoaded: true, suggested: 0, needsYou: 1).text == "1 needs you")
    }

    @Test func nothingLeftIsReadyInGreen() {
        let status = AppInformationPageStatus(isLoaded: true, suggested: 0, needsYou: 0)
        #expect(status.state == .ready)
        #expect(status.text == "Ready")
        #expect(status.tone == .ok)
        #expect(status.isReady)
    }

    @Test func whileLoadingTheCardHasASkeletonAndNoText() {
        let status = AppInformationPageStatus(isLoaded: false, suggested: 4, needsYou: 1)
        #expect(status.state == .loading)
        #expect(status.isLoading)
        #expect(status.text == nil)
        #expect(status.tone == .neutral)
    }

    @Test func aFailedLoadSaysSo() {
        let status = AppInformationPageStatus(isLoaded: false, hasFailed: true, suggested: 0, needsYou: 0)
        #expect(status.state == .failed)
        #expect(status.text == "Couldn’t load")
        #expect(status.tone == .warning)
        #expect(!status.isLoading)
    }

    /// A refresh that failed over loaded pages keeps their state.
    @Test func aFailureAfterLoadingKeepsTheState() {
        #expect(AppInformationPageStatus(isLoaded: true, hasFailed: true, suggested: 2, needsYou: 0).state == .suggested(2))
    }
}
