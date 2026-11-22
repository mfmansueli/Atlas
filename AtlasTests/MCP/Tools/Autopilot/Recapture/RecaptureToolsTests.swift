//
//  RecaptureToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// request_recapture, mark_captures_stale and request_page_recapture:
/// Claude Code asks to redo only some captures instead of a whole run. The
/// request waits for the person's Accept (or opens at once when they let
/// it), get_capture_plan then lists only those, and list_captures says
/// which are out of date.
@MainActor
@Suite("Recapture tools")
struct RecaptureToolsTests {
    /// Lumen's finished run, every capture in.
    private static func ready() -> AutopilotRun {
        var run = StudioDebugRuns.run(.ready)
        if run.captures.isEmpty { AutopilotTestFixtures.captureAll(&run) }
        return run
    }

    private static let german: [String: JSONValue] = [
        "targets": [["locale": "de-DE", "displayType": "iphone"]],
        "reason": "the phrases were rewritten", "evidence": "d038b58",
    ]

    @Test func theToolsAreInTheToolboxAndTheInstructions() {
        for name in ["request_recapture", "mark_captures_stale", "request_page_recapture"] {
            #expect(MCPToolbox.standard.toolNames.contains(name))
            #expect(MCPEndpoint.instructions.contains(name))
        }
        #expect(GetCapturePlanTool().definition.description.contains("request_recapture"))
        #expect(ListCapturesTool().definition.description.contains("request_recapture"))
        #expect(GetPageScreenshotsTool().definition.description.contains("request_page_recapture"))
    }

    @Test func aRequestWaitsForThePersonWithItsId() async throws {
        let fixtures = MCPAutopilotFixtures(Self.ready())
        fixtures.center.opensCaptureRuns = { false }
        let outcome = try await fixtures.call(RequestRecaptureTool(), Self.german)

        #expect(outcome.result["status"] == "queued", "\(outcome.result)")
        let id = try #require(outcome.result["requestId"]?.stringValue)
        let request = try #require(fixtures.center.recaptureRequests(for: MCPAutopilotFixtures.appID).first)
        #expect(request.id == id)
        #expect(request.targets.allSatisfy { $0.locale == "de-DE" && $0.displayType == .iPhone })
        #expect(request.targets.count == fixtures.run?.plan.screens(on: .iPhone).count)
        #expect(outcome.result["captures"]?.intValue == request.targets.count)
        #expect(request.headline.hasPrefix("Claude Code wants to redo \(request.targets.count) captures in de-DE"))
        #expect(fixtures.run?.stage == .ready, "Nothing opens before Accept")

        let plan = try await fixtures.call(GetCapturePlanTool(), [:])
        let queued = plan.result["queuedForNextPlan"]?.arrayValue?.first { $0["kind"] == "recapture" }
        #expect(queued?["requestId"]?.stringValue == id)
    }

    @Test func withTheSettingOnTheRunOpensAtOnce() async throws {
        let fixtures = MCPAutopilotFixtures(Self.ready())
        fixtures.center.opensCaptureRuns = { true }
        let outcome = try await fixtures.call(RequestRecaptureTool(), Self.german)

        #expect(outcome.result["status"] == "opened", "\(outcome.result)")
        let run = try #require(fixtures.run)
        #expect(run.isRecapturing)
        #expect(run.stage == .waiting)
        #expect(fixtures.center.recaptureRequests(for: MCPAutopilotFixtures.appID).isEmpty)

        let plan = try await fixtures.call(GetCapturePlanTool(), [:])
        let captures = plan.result["recapture"]?["captures"]?.arrayValue
        #expect(captures?.count == run.recapture?.targets.count)
        #expect(captures?.allSatisfy { $0["locale"] == "de-DE" && $0["done"] == false } == true)
        #expect(plan.result["total"]?.intValue == run.recapture?.targets.count)
    }

    @Test func aScreenOrSlotNarrowsItAndWhatDoesntMatchSaysWhy() async throws {
        let fixtures = MCPAutopilotFixtures(Self.ready())
        fixtures.center.opensCaptureRuns = { false }
        let outcome = try await fixtures.call(RequestRecaptureTool(), [
            "targets": [
                ["screen": "Today", "locale": "de-DE", "displayType": "iphone"],
                ["slot": 2, "locale": "de-DE", "displayType": "iphone"],
                ["screen": "Nowhere", "locale": "de-DE"],
                ["locale": "xx-XX"],
            ],
            "reason": "the phrases were rewritten",
        ])
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["captures"]?.intValue == 2)
        #expect(outcome.result["refused"]?.arrayValue?.count == 2)
    }

    @Test func itsRefusedWithoutARunOrCapturesOrWhileOneIsGoing() async throws {
        // Without a run it's made from the set's captures
        // (RecaptureWithoutRunToolsTests); with none either, refused.
        let none = MCPAutopilotFixtures()
        none.services.documentChange = { $0.captures = CaptureIndex() }
        let refused = try await none.call(RequestRecaptureTool(), Self.german)
        #expect(refused.result["status"] == "refused")

        let fixtures = MCPAutopilotFixtures(Self.ready())
        fixtures.center.opensCaptureRuns = { true }
        _ = try await fixtures.call(RequestRecaptureTool(), Self.german)
        let again = try await fixtures.call(RequestRecaptureTool(), Self.german)
        #expect(again.result["status"] == "refused")
        #expect(again.result["reason"]?.stringValue?.contains("capture-only run is open") == true)
    }

    @Test func aCaptureOutOfDateIsLabelledInListCaptures() async throws {
        let fixtures = MCPAutopilotFixtures(Self.ready())
        let marked = try await fixtures.call(MarkCapturesStaleTool(), [
            "targets": [["slot": 1, "locale": "en-US", "displayType": "iphone"]], "reason": "the Today screen was redesigned",
        ])
        #expect(marked.result["status"] == "marked", "\(marked.result)")
        #expect(marked.result["marked"]?.intValue == 1)

        let list = try await fixtures.call(ListCapturesTool(), ["locale": "en-US", "displayType": "iphone"])
        let first = list.result["captures"]?.arrayValue?.first { $0["slot"] == 1 }
        #expect(first?["stale"] == true)
        #expect(first?["staleReason"] == "the Today screen was redesigned")
        let second = list.result["captures"]?.arrayValue?.first { $0["slot"] == 2 }
        #expect(second?["stale"] == false)
    }

    @Test func markingNothingIsRefused() async throws {
        let fixtures = MCPAutopilotFixtures(Self.ready())
        let outcome = try await fixtures.call(MarkCapturesStaleTool(), [
            "targets": [["slot": 99, "locale": "en-US"]], "reason": "changed",
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["refused"]?.arrayValue?.count == 1)
    }

    // MARK: - Product pages

    private func pageCall(
        _ arguments: [String: JSONValue], opens: Bool, studio: PageShotsStudio
    ) async throws -> (MCPToolOutcome, AutopilotCenter) {
        let center = AutopilotTestFixtures.center()
        center.opensCaptureRuns = { opens }
        var storePage = DebugStorePageServices()
        storePage.screenshots = AutopilotTestFixtures.services(center)
        var workspace = MCPTestFixtures.workspace(storePage: storePage)
        workspace.services.productPages = DebugProductPagesServices()
        let pages = MCPProductPagesFixtures()
        let tool = RequestPageRecaptureTool(studio: studio, store: pages.store, analytics: pages.analytics)
        var all = arguments
        all["appId"] = "Lumen Journal"
        all["page"] = .string(PageShotsTestFixtures.pageName)
        all["reason"] = "the diary locks with Face ID on this page"
        let context = MCPToolContext(workspace: workspace, clientName: AutopilotTestFixtures.client)
        return try await (tool.call(MCPToolArguments(all), in: context), center)
    }

    @Test func aPageCapturesAtMostThreeScreensAgain() async throws {
        let (outcome, _) = try await pageCall(["screens": [1, 2, 3, 4], "locale": "en-US"], opens: false, studio: PageShotsStudio())
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("at most 3") == true)
    }

    @Test func aPageRequestWaitsWithoutRunningMakeScreenshotsFirst() async throws {
        let studio = PageShotsStudio()
        let (outcome, center) = try await pageCall(["screens": [1, 3], "locale": "en-US"], opens: false, studio: studio)
        #expect(outcome.result["status"] == "queued", "\(outcome.result)")
        let request = try #require(center.recaptureRequests(for: PageShotsTestFixtures.app.id).first)
        #expect(request.page?.slots == [0, 2])
        #expect(request.page?.pageName == PageShotsTestFixtures.pageName)
        #expect(studio.run(PageShotsTestFixtures.key) == nil)
    }

    @Test func withTheSettingOnThePageCapturesAgainAtOnce() async throws {
        let studio = PageShotsStudio()
        let (outcome, _) = try await pageCall(["screens": [2], "locale": "en-US", "displayType": "iphone"], opens: true, studio: studio)
        #expect(outcome.result["status"] == "opened", "\(outcome.result)")
        let run = try #require(studio.run(PageShotsTestFixtures.key))
        #expect(run.stage == .plan)
        #expect(run.recapture?.requested?.slots == [1])
        #expect(run.recapture?.uploadToken.isEmpty == false)
    }
}
#endif
