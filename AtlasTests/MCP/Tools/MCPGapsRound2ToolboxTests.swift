//
//  MCPGapsRound2ToolboxTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The tools the second round of MCP gaps added: each is in the toolbox,
/// the server's instructions name it, and reads never write.
@MainActor
@Suite("MCP gaps round 2: toolbox")
struct MCPGapsRound2ToolboxTests {
    private static let reads = [
        "get_pricing_strategy", "get_push_history", "get_settings", "get_overview", "get_asset_library", "get_analytics_changes",
    ]
    private static let proposals = [
        "propose_pricing_strategy", "propose_asset_library_cleanup", "propose_event_submission", "propose_grace_period",
        "propose_page_review_action", "propose_page_screenshot_files",
    ]

    @Test func everyNewToolIsInTheToolboxAndTheInstructions() {
        let names = MCPToolbox.standard.toolNames
        for name in Self.reads + Self.proposals {
            #expect(names.contains(name), "\(name) isn't in the toolbox")
            #expect(MCPEndpoint.instructions.contains(name) || name == "propose_page_screenshot_files", "\(name) isn't in the instructions")
        }
    }

    @Test func theReadsAreReadOnlyAndTheProposalsAreNot() {
        #expect(GetPricingStrategyTool().definition.isReadOnly)
        #expect(GetPushHistoryTool().definition.isReadOnly)
        #expect(GetSettingsTool().definition.isReadOnly)
        #expect(GetOverviewTool().definition.isReadOnly)
        #expect(GetAssetLibraryTool().definition.isReadOnly)
        #expect(GetAnalyticsChangesTool().definition.isReadOnly)
        #expect(!ProposePricingStrategyTool().definition.isReadOnly)
        #expect(!ProposeAssetLibraryCleanupTool().definition.isReadOnly)
        #expect(!ProposeEventSubmissionTool().definition.isReadOnly)
        #expect(!ProposeGracePeriodTool().definition.isReadOnly)
        #expect(!ProposePageReviewActionTool().definition.isReadOnly)
        #expect(!ProposePageScreenshotFilesTool().definition.isReadOnly)
    }

    @Test func theProposalsAskForTheRightPermission() {
        #expect(ProposePricingStrategyTool().definition.proposalKind == .prices)
        #expect(ProposeGracePeriodTool().definition.proposalKind == .prices)
        #expect(ProposeAssetLibraryCleanupTool().definition.proposalKind == .screenshots)
        #expect(ProposePageScreenshotFilesTool().definition.proposalKind == .screenshots)
        #expect(ProposeEventSubmissionTool().definition.proposalKind == .release)
        #expect(ProposePageReviewActionTool().definition.proposalKind == .release)
    }

    @Test func theDescriptionsKeepAtlasVoice() {
        let banned = ["simply", "just", "easily", "seamlessly", "powerful", "leverage", "magic", "please", "successfully"]
        let tools: [any MCPTool] = [
            GetPricingStrategyTool(), ProposePricingStrategyTool(), GetPushHistoryTool(), GetSettingsTool(), GetOverviewTool(),
            GetAssetLibraryTool(), ProposeAssetLibraryCleanupTool(), ProposeEventSubmissionTool(), GetAnalyticsChangesTool(),
            ProposeGracePeriodTool(), ProposePageReviewActionTool(), ProposePageScreenshotFilesTool(),
        ]
        for tool in tools {
            let text = tool.definition.description.lowercased()
            for word in banned {
                #expect(text.range(of: "\\b\(word)\\b", options: .regularExpression) == nil, "\(tool.definition.name) says “\(word)”")
            }
            #expect(!text.contains("!"), "\(tool.definition.name) has “!”")
        }
    }
}
