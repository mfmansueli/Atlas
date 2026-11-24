//
//  PageShotsLookToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// propose_page_look and report_page_capture (board 52): Claude Code sends
/// the three looks only when the person asked for a new look, each checked
/// like a template edit and drawn on the page's first screenshot; and the
/// screens it captured again, uploaded first, only when the person turned
/// on Capture Screens Again, at the device's full size.
@MainActor
@Suite("Page screenshots look and capture tools")
struct PageShotsLookToolsTests {
    typealias Test = PageShotsTestFixtures

    private let fixtures = MCPProductPagesFixtures()
    private let studio = PageShotsStudio()

    private var getTool: GetPageScreenshotsTool {
        GetPageScreenshotsTool(studio: studio, store: fixtures.store, analytics: fixtures.analytics, attachesCaptures: false)
    }

    private var lookTool: ProposePageLookTool { ProposePageLookTool(studio: studio) }
    private var captureTool: ReportPageCaptureTool { ReportPageCaptureTool(studio: studio) }

    private static let look: [String: JSONValue] = [
        "appId": "Lumen Journal", "page": "Private diary", "name": "Quiet Indigo", "rationale": "Calm and closed.", "base": "cinema",
    ]

    @Test func theToolsAreInTheToolboxAndTheInstructions() {
        for name in ["propose_page_look", "report_page_capture"] {
            #expect(MCPToolbox.standard.toolNames.contains(name))
            #expect(MCPEndpoint.instructions.contains(name))
        }
        #expect(ProposePageLookTool().definition.proposalKind == .screenshots)
        #expect(ReportPageCaptureTool().definition.proposalKind == .screenshots)
    }

    @Test func aLookIsRefusedUnlessThePersonAskedForANewOne() async throws {
        studio.begin(Test.run(plan: Test.plan()))
        let outcome = try await fixtures.call(lookTool, Self.look)
        #expect(outcome.result["status"]?.stringValue == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("didn’t ask for a new look") == true)
        #expect(studio.run(Test.key)?.design == nil)
    }

    @Test func aLookIsCheckedKeptAndDrawn() async throws {
        studio.begin(Test.run(plan: Test.plan()))
        studio.choose(look: .claudeDesign, for: Test.key)

        let read = try await fixtures.call(getTool, ["appId": "Lumen Journal", "page": "Private diary"])
        #expect(read.result["look"]?["choice"]?.stringValue == "claudeDesign")
        #expect(read.result["look"]?["starters"]?.arrayValue?.contains("cinema") == true)

        let outcome = try await fixtures.call(lookTool, Self.look)
        #expect(outcome.result["status"]?.stringValue == "received", "\(outcome.result)")
        #expect(outcome.result["received"]?.intValue == 1)
        #expect(outcome.images.count == 1)
        let design = try #require(studio.run(Test.key)?.design)
        #expect(design.candidates.map(\.name) == ["Quiet Indigo"])
        #expect(design.candidates.first?.source == MCPProductPagesFixtures.client)
        #expect(design.isReady)

        var wrongBase = Self.look
        wrongBase["base"] = "glitter"
        let refused = try await fixtures.call(lookTool, wrongBase)
        #expect(refused.result["status"]?.stringValue == "refused")
        #expect(refused.result["reason"]?.stringValue?.contains("default") == true)

        var badField = Self.look
        badField["name"] = "Broken"
        badField["ops"] = [["op": "replace", "path": "caption.headline.size", "value": "huge"]]
        let checked = try await fixtures.call(lookTool, badField)
        #expect(checked.result["status"]?.stringValue == "refused")
        #expect(studio.run(Test.key)?.design?.candidates.count == 1)

        // Sent again with how sure and details: they replace the look's.
        var sure = Self.look
        sure["confidence"] = 3
        sure["details"] = "Reviews call the app private 14 times."
        _ = try await fixtures.call(lookTool, sure)
        #expect(studio.run(Test.key)?.design?.candidates.first?.layers == SuggestionLayers(
            details: "Reviews call the app private 14 times.", confidence: .sure
        ))
        var long = Self.look
        long["rationale"] = .string(String(repeating: "x", count: 111))
        let tooLong = try await fixtures.call(lookTool, long)
        #expect(tooLong.result["reason"]?.stringValue == "rationale is 111 characters; at most 110. Move the rest to details.")
    }

    @Test func aCaptureIsRefusedUnlessThePersonTurnedItOn() async throws {
        studio.begin(Test.run(plan: Test.plan()))
        let outcome = try await fixtures.call(captureTool, [
            "appId": "Lumen Journal", "page": "Private diary", "screen": 5, "locale": "en-US", "displayType": "iphone", "upload": "pu-1",
        ])
        #expect(outcome.result["status"]?.stringValue == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("Capture Screens Again") == true)
    }

    @Test func anUploadedCaptureAtFullSizeIsKept() async throws {
        studio.begin(Test.run(plan: Test.plan(), locales: ["en-US", "de-DE"]))
        studio.setRecapture(true, for: Test.key)
        let run = try #require(studio.run(Test.key))

        let read = try await fixtures.call(getTool, ["appId": "Lumen Journal", "page": "Private diary"])
        let link = try #require(read.result["recapture"]?["uploadURL"]?.stringValue)
        #expect(link.contains("/page-shots/\(run.recapture?.uploadToken ?? "-")"))

        let small = studio.registerUpload(CaptureFile(id: "small", pixelSize: PixelSize(width: 1170, height: 2532)), for: run)
        let full = studio.registerUpload(CaptureFile(id: "lock", pixelSize: PixelSize(width: 1320, height: 2868)), for: run)
        var arguments: [String: JSONValue] = [
            "appId": "Lumen Journal", "page": "Private diary", "screen": 5, "locale": "en-US", "displayType": "iphone",
            "upload": .string(small.id), "notes": "Locked with Face ID.",
        ]
        let tooSmall = try await fixtures.call(captureTool, arguments)
        #expect(tooSmall.result["status"]?.stringValue == "refused")

        arguments["upload"] = "pu-unknown"
        await #expect(throws: MCPToolError.self) { try await fixtures.call(captureTool, arguments) }

        arguments["upload"] = .string(full.id)
        let kept = try await fixtures.call(captureTool, arguments)
        #expect(kept.result["status"]?.stringValue == "received", "\(kept.result)")
        #expect(kept.result["next"]?.stringValue?.contains("de-DE") == true)
        let capture = try #require(studio.run(Test.key)?.recapture?.captures.first)
        #expect(capture.slot == 4)
        #expect(capture.captureID == "lock")
        #expect(capture.notes == "Locked with Face ID.")
        #expect(studio.uploads[full.id] == nil)

        var wrongScreen = arguments
        wrongScreen["screen"] = 9
        await #expect(throws: MCPToolError.self) { try await fixtures.call(captureTool, wrongScreen) }
    }

    /// A capture lies the way the set does on its device: on Alba's iPad,
    /// a landscape set, a portrait capture came out cropped. The device's
    /// pixelSize and orientation come from the template.
    @Test func aCaptureTurnedTheOtherWayIsRefused() async throws {
        studio.begin(Test.run(plan: Test.plan()))
        studio.setRecapture(true, for: Test.key)
        let run = try #require(studio.run(Test.key))
        let read = try await fixtures.call(getTool, ["appId": "Lumen Journal", "page": "Private diary"])
        let iPhone = try #require(read.result["recapture"]?["devices"]?.arrayValue?.first)
        #expect(iPhone["orientation"]?.stringValue == "portrait")
        #expect(iPhone["pixelSize"]?.stringValue == PixelSize(width: 1320, height: 2868).title)

        let sideways = studio.registerUpload(CaptureFile(id: "sideways", pixelSize: PixelSize(width: 2868, height: 1320)), for: run)
        let outcome = try await fixtures.call(captureTool, [
            "appId": "Lumen Journal", "page": "Private diary", "screen": 1, "locale": "en-US", "displayType": "iphone",
            "upload": .string(sideways.id),
        ])
        #expect(outcome.result["status"]?.stringValue == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("portrait") == true)
        #expect(studio.run(Test.key)?.recapture?.captures.isEmpty == true)
    }
}
#endif
