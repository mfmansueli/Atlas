//
//  ReportReviewScreenshotRunToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `report_review_screenshot_run`: a Make Review Screenshots… run's steps
/// and stops, for Pricing's cards and the toolbar.
@MainActor
@Suite("report_review_screenshot_run")
struct ReportReviewScreenshotRunToolTests {
    private let runs = ReviewShotsRunCenter()
    private let appID = DebugFixtures.AppID.lumen

    private func report(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps, changes: ChangeQueue())
        return try await ReportReviewScreenshotRunTool(runs: runs).call(
            MCPToolArguments(["appId": "Lumen Journal"].merging(arguments) { $1 }),
            in: MCPToolContext(workspace: workspace, clientName: "Claude Code")
        )
    }

    @Test func stepsShowWhileItWorks() async throws {
        runs.start(appID: appID, client: "Claude Code", products: [.init(productID: "lumen.plus.annual", plan: "Annual")])
        let outcome = try await report(["status": "working", "productId": "lumen.plus.annual", "step": "Selecting Annual"])
        #expect(outcome.result["status"] == "saved")
        #expect(runs.run(for: appID)?.current == "lumen.plus.annual")
        #expect(runs.run(for: appID)?.toolbarText == "Capturing Annual · 1 of 1")
    }

    @Test func aStopKeepsWhy() async throws {
        runs.start(appID: appID, client: "Claude Code", products: [])
        _ = try await report(["status": "paywall_not_found", "tried": "Settings and the + button"])
        #expect(runs.run(for: appID)?.phase == .paywallNotFound(tried: "Settings and the + button"))
        _ = try await report(["status": "no_prices", "saw": "Empty plan list"])
        #expect(runs.run(for: appID)?.phase == .noPrices(saw: "Empty plan list"))
    }

    @Test func aRunAskedOutsideAtlasShowsToo() async throws {
        _ = try await report(["status": "working", "step": "Opened Lumen in Simulator"])
        #expect(runs.run(for: appID)?.client == "Claude Code")
        _ = try await report(["status": "done"])
        #expect(runs.run(for: appID) == nil, "Nothing arrived: nothing to show")
    }

    @Test func anUnknownStatusIsRefused() async {
        await #expect(throws: MCPToolError.self) { _ = try await report(["status": "sleeping"]) }
        #expect(MCPToolbox.standard.toolNames.contains("report_review_screenshot_run"))
    }
}
#endif
