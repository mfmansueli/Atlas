//
//  AssistantTextCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The server's check of card texts before a tool runs: driven by the
/// tool's schema, at any depth, and only for free-text fields.
@MainActor
@Suite("Assistant text check")
struct AssistantTextCheckTests {
    private let long = String(repeating: "x", count: 164)

    @Test func aTopLevelWhyOverItsLimitIsRefused() {
        let schema = MCPToolDefinition.schema(MCPToolDefinition.withLayers(["why": MCPToolDefinition.why("Why.")]))
        #expect(AssistantTextCheck.refusal(["why": "Short."], schema: schema) == nil)
        #expect(
            AssistantTextCheck.refusal(["why": .string(long)], schema: schema)
                == "why is 164 characters; at most 110. Move the rest to details."
        )
    }

    @Test func aBatchItemIsNamedByItsPlace() {
        let arguments: [String: JSONValue] = [
            "appId": "Lumen",
            "items": [
                ["field": "subtitle", "value": "A", "reason": "Fine."],
                ["field": "name", "value": "B", "reason": .string(long)],
            ],
        ]
        let refusal = AssistantTextCheck.refusal(arguments, schema: SuggestFieldsTool().definition.inputSchema)
        #expect(refusal == "items[1].reason is 164 characters; at most 110. Move the rest to details.")
    }

    @Test func detailsGlossAndConfidenceAreChecked() {
        let schema = SuggestFieldsTool().definition.inputSchema
        func item(_ extra: [String: JSONValue]) -> [String: JSONValue] {
            ["items": .array([.object(["field": "subtitle", "value": "A"].merging(extra) { _, new in new })])]
        }
        #expect(AssistantTextCheck.refusal(item(["details": .string(String(repeating: "d", count: 401))]), schema: schema)
            == "items[0].details is 401 characters; at most 400. Keep the numbers that decide it.")
        #expect(AssistantTextCheck.refusal(item(["gloss": .string(String(repeating: "g", count: 111))]), schema: schema)
            == "items[0].gloss is 111 characters; at most 110. Say what it means, not word for word.")
        #expect(AssistantTextCheck.refusal(item(["confidence": 4]), schema: schema)
            == "items[0].confidence is 4; send 1 (not very sure), 2 (fairly sure) or 3 (sure).")
        #expect(AssistantTextCheck.refusal(item(["details": "Every number.", "gloss": "Means this.", "confidence": 3]), schema: schema) == nil)
    }

    @Test func aWhyWithoutDetailsBesideItSaysToKeepOneSentence() {
        let schema = MCPToolDefinition.schema(["reason": MCPToolDefinition.shortWhy("Why.")])
        #expect(
            AssistantTextCheck.refusal(["reason": .string(long)], schema: schema)
                == "reason is 164 characters; at most 110. Keep one sentence."
        )
    }

    @Test func enumsAndOtherFieldsAreLeftAlone() {
        let schema = MCPToolDefinition.schema([
            "reason": ["type": "string", "enum": ["a", "b"]],
            "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
            "note": MCPToolDefinition.string("Anything."),
        ])
        #expect(AssistantTextCheck.refusal(["reason": .string(long), "confidence": "high", "note": .string(long)], schema: schema) == nil)
        // A field the schema doesn't have isn't checked either.
        #expect(AssistantTextCheck.refusal(["why": .string(long)], schema: MCPToolDefinition.schema()) == nil)
    }

    @Test func everyToolsSchemaIsWalkedWithoutRefusingShortTexts() {
        for tool in MCPToolbox.standard.tools {
            let schema = tool.definition.inputSchema
            #expect(AssistantTextCheck.refusal(["why": "Short.", "reason": "Short.", "details": "Short."], schema: schema) == nil)
        }
    }

    @Test func everyProposeToolOffersHowSure() {
        let tools = MCPToolbox.standard.tools.filter { $0.definition.name.hasPrefix("propose_") || $0.definition.name.hasPrefix("revise_") }
        #expect(tools.count > 40)
        for tool in tools {
            #expect(tool.definition.inputSchema.jsonString().contains("\"confidence\""), "\(tool.definition.name)")
        }
    }

    @Test func aTooLongReasonOnAQueuedChangeIsRefusedWithWhereTheRestGoes() {
        for tool: any MCPTool in [ProposeAppPriceTool(), ProposeAppVersionTool(), ProposeInAppEventTool(), ProposeIntroductoryOfferTool()] {
            let refusal = AssistantTextCheck.refusal(["reason": .string(long)], schema: tool.definition.inputSchema)
            #expect(refusal == "reason is 164 characters; at most 110. Move the rest to details.", "\(tool.definition.name)")
        }
        let offer = AssistantTextCheck.refusal(["reason": .string(long)], schema: ProposeWinBackOfferTool().definition.inputSchema)
        #expect(offer == "reason is 164 characters; at most 110. Move the rest to details.")
    }

    @Test func aRationaleIsAWhyLine() {
        let schema = MCPToolDefinition.schema(MCPToolDefinition.withLayers(["rationale": MCPToolDefinition.why("Why.")]))
        #expect(AssistantTextCheck.refusal(["rationale": "Short."], schema: schema) == nil)
        #expect(
            AssistantTextCheck.refusal(["rationale": .string(long)], schema: schema)
                == "rationale is 164 characters; at most 110. Move the rest to details."
        )
    }

    @Test func howSureOutOfRangeIsRefusedOnABatchItem() {
        let schema = ProposeListingTextTool().definition.inputSchema
        let arguments: [String: JSONValue] = ["proposals": [["locale": "de-DE", "field": "subtitle", "text": "A", "confidence": 0]]]
        #expect(AssistantTextCheck.refusal(arguments, schema: schema) == "proposals[0].confidence is 0; send 1 (not very sure), 2 (fairly sure) or 3 (sure).")
        #expect(AssistantTextCheck.refusal(["confidence": 5], schema: ProposePricesTool().definition.inputSchema)
            == "confidence is 5; send 1 (not very sure), 2 (fairly sure) or 3 (sure).")
        #expect(AssistantTextCheck.refusal(["gloss": .string(String(repeating: "g", count: 111))], schema: ProposeInAppTextsTool().definition.inputSchema)
            == "gloss is 111 characters; at most 110. Say what it means, not word for word.")
    }

    @Test func toolsThatKeepDetailsOfferThem() {
        let keepers: [any MCPTool] = [
            SuggestFieldsTool(), AddFindingTool(), ProposeCaptionsTool(), ProposeTemplateTool(), ProposeEventTextsTool(),
            ProposeProductPageTextsTool(), ProposeProductPageTool(), ProposePageTestTool(), ProposePageScreenshotsTool(),
            ProposeReleaseActionTool(), ProposeExportComplianceTool(), ProposeAppPriceTool(), ProposeAvailabilityTool(),
            ProposeAppVersionTool(), ProposeIntroductoryOfferTool(), ProposePromotionalOfferTool(), ProposeWinBackOfferTool(),
            ProposeOfferCodeTool(), ProposeInAppPurchaseOfferCodeTool(), ProposeInAppEventTool(), ProposeEventDetailsTool(),
            ProposeInAppReviewNoteTool(),
        ]
        for tool in keepers {
            #expect(tool.definition.inputSchema.jsonString().contains("\"details\""), "\(tool.definition.name)")
        }
    }
}
