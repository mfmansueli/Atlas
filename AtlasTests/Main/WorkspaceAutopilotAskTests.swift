//
//  WorkspaceAutopilotAskTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// What the Autopilot bar's actions ask Claude Code: proposals only,
/// with the run's purpose the section's asking buttons look for.
@Suite("WorkspaceAutopilotAsk")
struct WorkspaceAutopilotAskTests {
    @Test func whatsNewNamesTheVersionAndProposes() throws {
        let ask = try #require(WorkspaceAutopilotAsk.make(.writeWhatsNew, app: "Lumen", version: "1.4"))
        #expect(ask.prompt.contains("version 1.4"))
        #expect(ask.prompt.contains("suggest_fields"))
        #expect(ask.subject == "Store Page · What’s New")
    }

    @Test func sectionAsksShareTheSectionsPurpose() throws {
        #expect(try #require(WorkspaceAutopilotAsk.make(.draftReplies, app: "Lumen")).purpose == ReviewsAskPrompt.purpose)
        #expect(try #require(WorkspaceAutopilotAsk.make(.writeEventTexts, app: "Lumen")).purpose == InAppEventsAskPrompt.purpose)
        #expect(try #require(WorkspaceAutopilotAsk.make(.writeRetentionOffer, app: "Lumen")).purpose == RetentionAskPrompts.purpose)
        #expect(try #require(WorkspaceAutopilotAsk.make(.recaptureSome, app: "Lumen")).purpose == .autopilot)
    }

    @Test func recaptureAsksOnlyForWhatChanged() throws {
        let ask = try #require(WorkspaceAutopilotAsk.make(.recaptureSome, app: "Lumen"))
        #expect(ask.prompt.contains("request_recapture"))
        #expect(ask.prompt.contains("mark_captures_stale"))
        #expect(ask.prompt.contains("Don't start a new run"))
    }

    @Test func analyticsNeverQuotesWhatsTooFewToTell() throws {
        for action in [WorkspaceAutopilotAction.findWhatToTry, .explainChange, .suggestPrices] {
            let ask = try #require(WorkspaceAutopilotAsk.make(action, app: "Lumen"))
            #expect(ask.prompt.contains("tooFewToTell"), "\(action)")
        }
    }
}
