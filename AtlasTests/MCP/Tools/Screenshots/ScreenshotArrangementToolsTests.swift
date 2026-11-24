//
//  ScreenshotArrangementToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_screenshot_removal`, `propose_screenshot_order` and the set
/// `get_screenshot_context` lists for a language and device, on Lumen
/// Journal's sample document: suggestions wait in the document, the set
/// doesn't change until the person accepts, and what can't be done is
/// refused with why.
@MainActor
@Suite("Screenshot removal and order tools")
struct ScreenshotArrangementToolsTests {
    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], document: ScreenshotsDocument = ScreenshotsDebugDocuments.standard
    ) async throws -> (MCPToolOutcome, CenteredScreenshotsServices) {
        let (workspace, services) = MCPScreenshotsFixtures.workspace(document)
        return try await (MCPScreenshotsFixtures.call(tool, arguments, in: workspace), services)
    }

    private func arguments(_ extra: [String: JSONValue], locale: String = "de-DE") -> [String: JSONValue] {
        var arguments: [String: JSONValue] = ["locale": .string(locale), "displayType": "iphone", "reason": "Screens 2 and 4 repeat each other."]
        arguments.merge(extra) { _, new in new }
        return arguments
    }

    /// The set's IDs, as `get_screenshot_context` lists them.
    private func ids(_ locale: String = "de-DE") async throws -> [String] {
        let (outcome, _) = try await call(GetScreenshotContextTool(), ["locale": .string(locale), "displayType": "iphone"])
        return outcome.result["set"]?["screenshots"]?.arrayValue?.compactMap { $0["id"]?.stringValue } ?? []
    }

    // MARK: - Reading

    @Test func theContextListsASetsScreenshotsByPositionAndID() async throws {
        let (outcome, _) = try await call(GetScreenshotContextTool(), ["locale": "de-DE", "displayType": "iphone"])
        let set = try #require(outcome.result["set"])
        #expect(set["locale"] == "de-DE")
        #expect(set["displayType"] == "iphone")
        let screenshots = try #require(set["screenshots"]?.arrayValue)
        #expect(!screenshots.isEmpty)
        #expect(screenshots.first?["position"] == 1)
        #expect(screenshots.first?["id"] == "template:1")
        #expect(screenshots.first?["madeBy"] == "template")
        #expect(set["deletedOnPush"] == 0)

        let (plain, _) = try await call(GetScreenshotContextTool(), [:])
        #expect(plain.result["set"] == nil)
    }

    // MARK: - Removal

    @Test func aRemovalWaitsWithoutChangingTheSet() async throws {
        let (outcome, services) = try await call(ProposeScreenshotRemovalTool(), arguments(["positions": [2, 4]]))
        #expect(outcome.result["status"] == "queued")
        let id = try #require(outcome.result["proposalId"]?.stringValue)
        #expect(id.hasPrefix("sp-"))
        let all = try await ids()
        #expect(outcome.result["after"]?.arrayValue?.compactMap(\.stringValue) == all.enumerated().filter { ![1, 3].contains($0.offset) }.map(\.element))
        #expect(outcome.logLines.first?.outcome == .proposed)

        let document = try #require(services.storedDocument)
        let arrangement = try #require(document.handArrangements?.first)
        #expect(arrangement.id == id)
        #expect(arrangement.action == .removal)
        #expect(arrangement.places.map(\.position) == [1, 3])
        #expect(arrangement.client == "Claude Code")
        #expect(arrangement.isWaiting)
        #expect(document.handSet(locale: "de-DE", displayType: .iPhone) == nil)
    }

    @Test func aRemovalNamesScreenshotsByIDToo() async throws {
        let (outcome, services) = try await call(ProposeScreenshotRemovalTool(), arguments(["screenshotIds": ["template:1"]]))
        #expect(outcome.result["status"] == "queued")
        #expect(services.storedDocument?.handArrangements?.first?.places.first?.mcpID == "template:1")
    }

    @Test func aNewerRemovalReplacesTheWaitingOne() async throws {
        let (workspace, services) = MCPScreenshotsFixtures.workspace()
        _ = try await MCPScreenshotsFixtures.call(ProposeScreenshotRemovalTool(), arguments(["positions": [2]]), in: workspace)
        _ = try await MCPScreenshotsFixtures.call(ProposeScreenshotRemovalTool(), arguments(["positions": [3]]), in: workspace)
        let arrangements = services.storedDocument?.handArrangements ?? []
        #expect(arrangements.count == 1)
        #expect(arrangements.first?.places.map(\.position) == [2])
    }

    @Test func whatARemovalCantDoIsRefused() async throws {
        let (outOfRange, _) = try await call(ProposeScreenshotRemovalTool(), arguments(["positions": [99]]))
        #expect(outOfRange.result["status"] == "refused")
        #expect(outOfRange.result["reason"]?.stringValue?.contains("There’s no screenshot 99") == true)

        let (unknown, _) = try await call(ProposeScreenshotRemovalTool(), arguments(["screenshotIds": ["file:nope"]]))
        #expect(unknown.result["reason"]?.stringValue?.contains("No screenshot “file:nope”") == true)

        let (twice, _) = try await call(ProposeScreenshotRemovalTool(), arguments(["positions": [1], "screenshotIds": ["template:1"]]))
        #expect(twice.result["reason"] == "A screenshot is named twice. Name each one once.")

        let count = try await ids("en-US").count
        let every = JSONValue.array((1...count).map { .int($0) })
        let (everything, services) = try await call(ProposeScreenshotRemovalTool(), arguments(["positions": every], locale: "en-US"))
        #expect(everything.result["status"] == "refused")
        #expect(everything.result["reason"]?.stringValue?.contains("primary language") == true)
        #expect(services.storedDocument?.handArrangements == nil)

        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeScreenshotRemovalTool(), arguments([:]))
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeScreenshotRemovalTool(), ["locale": "de-DE", "displayType": "appletv", "reason": "x", "positions": [1]])
        }
    }

    // MARK: - Order

    @Test func anOrderWaitsWithEveryScreenshotInItsNewPlace() async throws {
        let all = try await ids()
        let order: [Int] = [2, 1] + Array(3...all.count)
        let (outcome, services) = try await call(ProposeScreenshotOrderTool(), arguments(["order": .array(order.map { .int($0) })]))
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["after"]?.arrayValue?.compactMap(\.stringValue) == order.map { all[$0 - 1] })
        let arrangement = try #require(services.storedDocument?.handArrangements?.first)
        #expect(arrangement.action == .order)
        #expect(arrangement.places.map(\.position) == order.map { $0 - 1 })
    }

    @Test func anOrderByIDs() async throws {
        let all = try await ids()
        let (outcome, _) = try await call(ProposeScreenshotOrderTool(), arguments(["screenshotIds": .array(all.reversed().map { .string($0) })]))
        #expect(outcome.result["status"] == "queued")
    }

    @Test func anOrderThatLeavesSomeOutOrChangesNothingIsRefused() async throws {
        let all = try await ids()
        let (short, _) = try await call(ProposeScreenshotOrderTool(), arguments(["order": [2, 1]]))
        #expect(short.result["status"] == "refused")
        #expect(short.result["reason"]?.stringValue?.contains("propose_screenshot_removal") == true)

        let same = (1...all.count).map { JSONValue.int($0) }
        let (unchanged, _) = try await call(ProposeScreenshotOrderTool(), arguments(["order": .array(same)]))
        #expect(unchanged.result["reason"] == "That’s how the set is already: nothing would change.")

        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeScreenshotOrderTool(), arguments(["order": [1], "screenshotIds": ["template:1"]]))
        }
    }

    @Test func aRemovalKeepsItsDetailsAndHowSure() async throws {
        let extra: [String: JSONValue] = ["positions": [2], "details": "Screen 2 shows the same list as screen 4.", "confidence": 2]
        let (_, services) = try await call(ProposeScreenshotRemovalTool(), arguments(extra))
        let arrangement = try #require(services.storedDocument?.handArrangements?.first)
        #expect(arrangement.layers == SuggestionLayers(details: "Screen 2 shows the same list as screen 4.", confidence: .fairlySure))
    }

    @Test func everyHandToolRefusesALongReasonAndPointsToDetails() {
        let long = String(repeating: "r", count: 120)
        let tools: [any MCPTool] = [ProposeScreenshotRemovalTool(), ProposeScreenshotOrderTool(), ProposeScreenshotFileTool()]
        for tool in tools {
            let refusal = AssistantTextCheck.refusal(["reason": .string(long)], schema: tool.definition.inputSchema)
            #expect(refusal == "reason is 120 characters; at most 110. Move the rest to details.", "\(tool.definition.name)")
            #expect(AssistantTextCheck.refusal(["confidence": 0], schema: tool.definition.inputSchema) != nil, "\(tool.definition.name)")
        }
    }

    @Test func anArrangementSavedBeforeLayersStillDecodes() throws {
        var arrangement = ScreenshotHandArrangement(
            id: "sp-1", client: "Claude Code", receivedAt: Date(timeIntervalSinceReferenceDate: 0), locale: "de-DE", displayType: .iPhone,
            action: .removal, places: [], reason: "Repeats screen 4.", layers: SuggestionLayers(confidence: .sure)
        )
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(arrangement)) as? [String: Any])
        object["layers"] = nil
        let decoded = try JSONDecoder().decode(ScreenshotHandArrangement.self, from: JSONSerialization.data(withJSONObject: object))
        arrangement.layers = nil
        #expect(decoded == arrangement)
    }

    @Test func bothToolsAreInTheToolboxAsScreenshotProposals() {
        let names = MCPToolbox.standard.tools.map(\.definition.name)
        #expect(names.contains("propose_screenshot_removal"))
        #expect(names.contains("propose_screenshot_order"))
        #expect(ProposeScreenshotRemovalTool().definition.proposalKind == .screenshots)
        #expect(ProposeScreenshotOrderTool().definition.proposalKind == .screenshots)
        #expect(!ProposeScreenshotFileTool().definition.description.contains("can’t delete"))
        #expect(ProposeScreenshotFileTool().definition.description.contains("propose_screenshot_removal"))
    }
}
#endif
