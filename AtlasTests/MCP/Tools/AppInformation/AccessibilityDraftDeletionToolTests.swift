//
//  AccessibilityDraftDeletionToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_accessibility_draft_deletion` on Lumen's sample: the iPad
/// draft waits as Delete Draft until the person accepts it; iPhone's
/// published declaration is only replaced.
@MainActor
@Suite("propose_accessibility_draft_deletion")
struct AccessibilityDraftDeletionToolTests {
    private let services = DebugAppInformationServices()
    private let changes = ChangeQueue()

    private func call(_ device: String) async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(changes: changes, appInformation: services)
        return try await ProposeAccessibilityDraftDeletionTool().call(MCPToolArguments([
            "appId": "Lumen", "device": .string(device), "reason": "Voice Control isn't supported on iPad yet.",
        ]), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    @Test func theIPadDraftWaitsUntilThePersonAccepts() async throws {
        let outcome = try await call("ipad")
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.change(id: outcome.result["changeId"]?.stringValue ?? ""))
        #expect(change.newValue == "Delete draft")
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.awaitingAcceptance != nil)
        #expect(change.requests.first?.method == .delete)
        let again = try await call("ipad")
        #expect(again.result["status"] == "unchanged")
    }

    @Test func aPublishedDeclarationIsRefused() async throws {
        let outcome = try await call("iphone")
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("suggest_fields") == true)
        await #expect(throws: (any Error).self) { try await call("toaster") }
    }

    @Test func getAppInformationSaysWhichDevicesHaveADraft() async throws {
        let workspace = MCPTestFixtures.workspace(changes: changes, appInformation: services)
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code")
        let outcome = try await GetAppInformationTool().call(MCPToolArguments(["appId": "Lumen"]), in: context)
        let pages = try #require(outcome.result["pages"]?.arrayValue)
        let accessibility = try #require(pages.first { $0["page"] == "accessibility" })
        let devices = try #require(accessibility["devices"]?.arrayValue)
        #expect(devices.first { $0["device"] == "ipad" }?["hasDraft"] == true)
        #expect(devices.first { $0["device"] == "iphone" }?["hasDraft"] == false)
    }
}
#endif
