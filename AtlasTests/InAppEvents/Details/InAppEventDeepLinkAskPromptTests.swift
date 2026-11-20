//
//  InAppEventDeepLinkAskPromptTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Check in the Code and Make It Work… ask the person's Claude Code:
/// how the link must work for App Review (cold launch and already open,
/// after onboarding, before the event starts, no paywall for a free
/// event, home for an unknown one), tried with `xcrun simctl openurl`,
/// and reported with `report_deep_link_check`.
@Suite("In-App Events · deep link prompts")
struct InAppEventDeepLinkAskPromptTests {
    typealias Data = InAppEventsTestData

    @Test func checkingOnlyReadsTriesAndReports() {
        let text = InAppEventDeepLinkAskPrompt.text(.check, app: "Lumen Journal", appID: Data.app.id, event: Data.winter, deepLink: "lumen://challenge/winter")
        #expect(text.contains("“Winter Reflection Challenge” (app \(Data.app.id), event winter) needs its deep link lumen://challenge/winter"))
        #expect(text.contains("without changing the project"))
        #expect(text.contains("xcrun simctl openurl booted '<link>'"))
        #expect(text.contains("report_deep_link_check"))
        #expect(text.contains("before the event starts it shows the event and its start date"))
        #expect(text.contains("an unknown or ended event opens the normal home screen"))
        #expect(text.contains("after onboarding"))
        #expect(!text.contains("bump the build number"))
        #expect(!text.contains("propose_event_details"))
    }

    @Test func makingItWorkChangesTheProjectAndBumpsTheBuild() {
        var event = Data.winter
        event.deepLink = nil
        let text = InAppEventDeepLinkAskPrompt.text(.makeItWork, app: "Lumen Journal", appID: Data.app.id, event: event, deepLink: nil)
        #expect(text.contains("a deep link (it has none yet)"))
        #expect(text.contains("propose it with propose_event_details"))
        #expect(text.contains("bump the build number (CURRENT_PROJECT_VERSION) by one"))
        #expect(text.contains("don't archive or upload the build"))
        #expect(text.contains("Never push and never submit the event for review"))
    }

    @Test func aFreeEventNeverLandsOnAPaywall() {
        #expect(InAppEventDeepLinkAskPrompt.requirements(isFree: true).contains("NO_COST_ASSOCIATED"))
        #expect(!InAppEventDeepLinkAskPrompt.requirements(isFree: false).contains("paywall"))
        #expect(InAppEventDeepLinkAskPrompt.purpose(.check, eventID: "1") != InAppEventDeepLinkAskPrompt.purpose(.check, eventID: "2"))
    }
}
