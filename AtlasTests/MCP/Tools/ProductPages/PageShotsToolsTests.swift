//
//  PageShotsToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// get_page_screenshots and propose_page_screenshots (board 52): Claude
/// Code reads Private diary's run, the default set's screens and the
/// page's audience, and sends the plan Atlas checks and keeps; there's
/// nothing to plan until the person presses Make Screenshots for This
/// Page, and nothing while Autopilot lays the set out.
@MainActor
@Suite("Page screenshots tools")
struct PageShotsToolsTests {
    typealias Test = PageShotsTestFixtures

    private let fixtures = MCPProductPagesFixtures()
    private let studio = PageShotsStudio()

    private var getTool: GetPageScreenshotsTool {
        GetPageScreenshotsTool(studio: studio, store: fixtures.store, analytics: fixtures.analytics, attachesCaptures: false)
    }

    private var proposeTool: ProposePageScreenshotsTool { ProposePageScreenshotsTool(studio: studio) }

    private static let screens: JSONValue = [
        Test.screen(5, ["en-US": "Locked with Face ID", "de-DE": "Mit Face ID gesperrt"]),
        Test.screen(1, ["en-US": "Write what you can’t say", "de-DE": "Schreib, was du denkst"]),
    ]

    @Test func theToolsAreInTheToolboxAndTheInstructions() {
        let names: Set = ["get_page_screenshots", "propose_page_screenshots"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        #expect(GetPageScreenshotsTool().definition.isReadOnly)
        #expect(ProposePageScreenshotsTool().definition.proposalKind == .screenshots)
        for name in names {
            #expect(MCPEndpoint.instructions.contains(name))
        }
    }

    @Test func withoutARunThereIsNothingToPlan() async throws {
        let outcome = try await fixtures.call(getTool, ["appId": "Lumen Journal", "page": "Private diary"])
        #expect(outcome.result["status"]?.stringValue == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("Make Screenshots for This Page") == true)
    }

    @Test func theRunIsReadWithTheDefaultSetsScreensAndThePagesAudience() async throws {
        studio.begin(Test.run(stage: .planning, displays: [.iPhone, .iPad], claudeRunID: UUID()))
        let outcome = try await fixtures.call(getTool, ["appId": "Lumen Journal", "page": "private diary"])
        #expect(outcome.result["status"]?.stringValue != "refused")
        let result = outcome.result
        #expect(result["page"]?["name"]?.stringValue == "Private diary")
        #expect(result["page"]?["isDraft"]?.boolValue == true)
        #expect(result["page"]?["audience"]?.stringValue == Test.run().note)
        let screens = try #require(result["screens"]?.arrayValue)
        #expect(screens.count == ScreenshotsSampleData.slotNames.count)
        #expect(screens.first?["name"]?.stringValue == "Today")
        #expect(screens.first?["defaultCaption"]?["headline"]?.stringValue?.isEmpty == false)
        #expect(result["languages"]?.arrayValue?.compactMap(\.stringValue) == Test.languages)
        #expect(result["primaryLanguage"]?.stringValue == "en-US")
        #expect(result["run"]?["stage"]?.stringValue == "planning")
        #expect(result["capturesAttached"]?.boolValue == false)
    }

    @Test func aPlanIsCheckedAndKeptForThePerson() async throws {
        studio.begin(Test.run(stage: .planning, displays: [.iPhone, .iPad], claudeRunID: UUID()))
        let outcome = try await fixtures.call(proposeTool, [
            "appId": "Lumen Journal", "page": "Private diary", "angle": "Privacy first.", "reason": "The lock first.",
            "screens": Self.screens, "languages": ["en-US", "de-DE"],
        ])
        #expect(outcome.result["status"]?.stringValue == "planned", "\(outcome.result)")
        #expect(outcome.result["languagesWithEveryCaption"]?.arrayValue?.compactMap(\.stringValue) == ["en-US", "de-DE"])
        #expect(outcome.result["missingLanguages"]?.arrayValue?.compactMap(\.stringValue) == ["ja", "ar-SA"])
        let run = try #require(studio.run(Test.key))
        #expect(run.plan?.screens.map(\.slot) == [4, 0])
        #expect(run.plan?.source == MCPProductPagesFixtures.client)
        #expect(run.stage == .planning)
        #expect(run.locales == ["en-US", "de-DE"])
    }

    @Test func nothingIsTakenWhileAutopilotLaysTheSetOut() async throws {
        studio.begin(Test.run(stage: .making, plan: Test.plan()))
        let outcome = try await fixtures.call(proposeTool, [
            "appId": "Lumen Journal", "page": "Private diary", "angle": "Search first.", "screens": Self.screens,
        ])
        #expect(outcome.result["status"]?.stringValue == "refused")
        #expect(studio.run(Test.key)?.plan?.angle == "Privacy first.")
    }
}
#endif
