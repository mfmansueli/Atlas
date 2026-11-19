//
//  AssistantsPermissionsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Settings → AI Assistants → "Assistants may suggest" (board 48): the
/// design's six switches, what each tool asks for, and choices saved
/// before the new ones.
@MainActor
@Suite("Assistants may suggest")
struct AssistantsPermissionsTests {
    @Test func theDesignsSwitches() {
        #expect(MCPProposalKind.allCases.map(\.title) == [
            "Store text", "Screenshot templates and captions", "Prices", "App Information answers", "Replies to reviews",
            "Event and header artwork",
        ])
    }

    /// Saved before replies and artwork had their own switch: those start on,
    /// the four saved choices stay.
    @Test func olderChoicesLeaveTheNewSwitchesOn() {
        let allowed = MCPServerController.allowedProposals(saved: ["storeText"])
        #expect(allowed == [.storeText, .reviewReplies, .artwork])
        #expect(MCPServerController.allowedProposals(saved: nil) == Set(MCPProposalKind.allCases))
    }

    @Test func eachToolAsksForItsSwitch() {
        #expect(ProposeReviewRepliesTool().definition.proposalKind == .reviewReplies)
        #expect(ProposeReviewThemesTool().definition.proposalKind == .reviewReplies)
        #expect(ProposeEventArtworkTool().definition.proposalKind == .artwork)
        #expect(ProposeArtworkVariantTool().definition.proposalKind == .artwork)
        #expect(ProposeCaptionsTool().definition.proposalKind == .screenshots)
    }

    @Test func theActivitySummaryCountsThisWeeksRefusals() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func entry(_ outcome: MCPCallOutcome, daysAgo: Double) -> MCPLogEntry {
            MCPLogEntry(date: now.addingTimeInterval(-daysAgo * 86400), client: "Claude Code", tool: "propose_prices", target: "Lumen", outcome: outcome)
        }
        #expect(AssistantActivitySheet.summary(of: [], now: now) == "Nothing yet.")
        #expect(AssistantActivitySheet.summary(of: [entry(.read, daysAgo: 1)], now: now) == "Nothing was refused this week.")
        let log = [entry(.refused, daysAgo: 1), entry(.refused, daysAgo: 2), entry(.refused, daysAgo: 9), entry(.proposed, daysAgo: 1)]
        #expect(AssistantActivitySheet.summary(of: log, now: now) == "2 calls were refused this week, each with its reason.")
    }
}
