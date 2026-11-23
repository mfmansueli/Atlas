//
//  AssistantsPermissionsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Settings → AI Assistants → "Assistants may suggest" (board 48): the
/// design's six switches and release actions' own, what each tool asks
/// for, and choices saved before the new ones.
@MainActor
@Suite("Assistants may suggest")
struct AssistantsPermissionsTests {
    @Test func theDesignsSwitches() {
        #expect(MCPProposalKind.allCases.map(\.title) == [
            "Store text", "Screenshot templates and captions", "Prices", "App Information answers", "Replies to reviews",
            "Event and header artwork", "Release actions",
        ])
        #expect(MCPProposalKind.release.refusal.contains("release actions is turned off"))
        #expect(MCPProposalKind.release.caption?.isEmpty == false)
    }

    /// Saved before replies and artwork had their own switch: those start on,
    /// the four saved choices stay, and release actions follow store text,
    /// whose switch they were under.
    @Test func olderChoicesLeaveTheNewSwitchesOn() {
        let allowed = MCPServerController.allowedProposals(saved: ["storeText"])
        #expect(allowed == [.storeText, .reviewReplies, .artwork, .release])
        #expect(MCPServerController.allowedProposals(saved: ["prices"]) == [.prices, .reviewReplies, .artwork])
        #expect(MCPServerController.allowedProposals(saved: nil) == Set(MCPProposalKind.allCases))
    }

    /// Saved with the switches there were: a newer one turned off stays
    /// off, and one added since starts as its former switch says.
    @Test func choicesSavedWithTheKnownSwitchesKeepTheNewerOnesOff() {
        let everyKind = MCPProposalKind.allCases.map(\.rawValue)
        #expect(MCPServerController.allowedProposals(saved: ["storeText"], known: everyKind) == [.storeText])
        let beforeRelease = MCPProposalKind.allCases.filter { $0 != .release }.map(\.rawValue)
        #expect(MCPServerController.allowedProposals(saved: ["storeText", "artwork"], known: beforeRelease) == [.storeText, .artwork, .release])
        #expect(MCPServerController.allowedProposals(saved: ["artwork"], known: beforeRelease) == [.artwork])
    }

    @Test func turningReleaseActionsOffIsRememberedAfterARelaunch() throws {
        let name = "AssistantsPermissionsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = MCPTestFixtures.controller(defaults: defaults)
        #expect(first.allows(.release))
        first.setAllowed(.release, false)
        first.setAllowed(.artwork, false)
        let relaunched = MCPTestFixtures.controller(defaults: defaults)
        #expect(!relaunched.allows(.release))
        #expect(!relaunched.allows(.artwork))
        #expect(relaunched.allows(.storeText))
    }

    @Test func eachToolAsksForItsSwitch() {
        #expect(ProposeReviewRepliesTool().definition.proposalKind == .reviewReplies)
        #expect(ProposeReviewThemesTool().definition.proposalKind == .reviewReplies)
        #expect(ProposeEventArtworkTool().definition.proposalKind == .artwork)
        #expect(ProposeArtworkVariantTool().definition.proposalKind == .artwork)
        #expect(ProposeCaptionsTool().definition.proposalKind == .screenshots)
        #expect(ProposeReleaseActionTool().definition.proposalKind == .release)
        #expect(GetReleaseTool().definition.proposalKind == nil)
        #expect(WithdrawReleaseActionTool().definition.proposalKind == nil)
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
