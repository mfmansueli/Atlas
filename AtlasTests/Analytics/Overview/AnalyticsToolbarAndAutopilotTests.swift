//
//  AnalyticsToolbarAndAutopilotTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("Analytics · the toolbar's line and the Autopilot bar before the first reports")
struct AnalyticsToolbarAndAutopilotTests {
    private func status(_ facts: WorkspaceSectionStatus.Facts, waiting: Int = 0) -> String? {
        WorkspaceSectionStatus(section: .analytics, waiting: waiting, facts: facts).stateText
    }

    @Test func theLineSaysWhatAnalyticsIsDoing() {
        var facts = WorkspaceSectionStatus.Facts()
        facts.days = 28
        facts.analyticsStatus = AnalyticsAvailability.waitingForApple(asked: nil).toolbarText
        #expect(status(facts) == "Waiting for Apple’s first reports")
        facts.analyticsStatus = AnalyticsAvailability.notSetUp.toolbarText
        #expect(status(facts) == "Not set up")
    }

    @Test func otherwiseTheUsualLine() {
        var facts = WorkspaceSectionStatus.Facts()
        facts.days = 28
        facts.analyticsStatus = AnalyticsAvailability.ready(since: nil, days: 90).toolbarText
        #expect(status(facts, waiting: 2) == "Last 28 days · 2 new findings")
    }

    @Test func beforeTheFirstReportsTheBarOnlyAsks() {
        let actions = WorkspaceAutopilotAction.actions(for: .analytics, detail: .analyticsBeforeReports)
        #expect(actions == [.askWhatAnalyticsShows])
        #expect(WorkspaceAutopilotAction.askWhatAnalyticsShows.title() == "Ask What Analytics Shows…")
        #expect(WorkspaceAutopilotAction.askWhatAnalyticsShows.asksAssistant)
        #expect(WorkspaceAutopilotAsk.make(.askWhatAnalyticsShows, app: "Lumen")?.prompt.contains("Lumen") == true)
        #expect(WorkspaceAutopilotAction.actions(for: .analytics, detail: nil) == [.findWhatToTry, .explainChange])
        #expect(WorkspaceAutopilotAction.actions(for: .storePage, detail: .analyticsBeforeReports) == WorkspaceAutopilotAction.actions(for: .storePage))
    }
}
