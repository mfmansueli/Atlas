//
//  RecaptureWithoutRunToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// request_recapture when the app has no saved Autopilot run (Alba on
/// 2026-11-22: "has no Autopilot run to redo captures from" with 18
/// captures in ja): the run is made from the captures the set uses, it
/// queues or opens as with a run, get_capture_plan then lists only those,
/// and only what has no capture, or App Preview moments, is refused.
@MainActor
@Suite("Recapture tools without a run")
struct RecaptureWithoutRunToolsTests {
    /// Alba's request, as Claude Code sent it.
    private static let japanese: [String: JSONValue] = [
        "targets": [["locale": "ja"]], "reason": "the Japanese phrases were rewritten", "evidence": "d038b58",
    ]

    /// No run, and Alba's captures in the set.
    private static func fixtures(opens: Bool, document: ScreenshotsDocument = AlbaCaptureFixtures.document()) -> MCPAutopilotFixtures {
        let fixtures = MCPAutopilotFixtures()
        fixtures.services.documentChange = { $0 = document }
        fixtures.center.opensCaptureRuns = { opens }
        return fixtures
    }

    private static var appID: StoreApp.ID { MCPAutopilotFixtures.appID }

    @Test func alba18JapaneseCapturesAreAskedForWithoutARun() async throws {
        let fixtures = Self.fixtures(opens: false)
        let outcome = try await fixtures.call(RequestRecaptureTool(), Self.japanese)

        #expect(outcome.result["status"] == "queued", "\(outcome.result)")
        #expect(outcome.result["captures"]?.intValue == 18)
        #expect(outcome.result["fromCaptures"]?.stringValue != nil)
        let request = try #require(fixtures.center.recaptureRequests(for: Self.appID).first)
        let targets = request.targets
        #expect(targets.count == 18)
        #expect(targets.allSatisfy { $0.locale == "ja" })
        #expect(targets.count(where: { $0.displayType == .iPhone }) == 6)
        #expect(targets.count(where: { $0.displayType == .iPad }) == 6)
        let duo = targets.filter { $0.displayType == .iPhoneDuo }
        #expect(duo.count == 6)
        let plan = try #require(request.fromCaptures?.plan)
        #expect(duo.map { plan.slot(of: $0.screenID) ?? -1 } == Array(0..<6))
        #expect(duo.map(\.duoPose) == [.open, .closed, .open, .closed, .open, .closed])
        #expect(Set(targets.map { plan.slot(of: $0.screenID) ?? -1 }) == Set(0..<6))
        #expect(fixtures.run == nil, "Nothing opens before Accept")
    }

    @Test func afterAcceptGetCapturePlanListsOnlyThe18() async throws {
        let fixtures = Self.fixtures(opens: false)
        let outcome = try await fixtures.call(RequestRecaptureTool(), Self.japanese)
        let id = try #require(outcome.result["requestId"]?.stringValue)
        try fixtures.center.acceptRecapture(id, appID: Self.appID)

        let plan = try await fixtures.call(GetCapturePlanTool(), [:])
        let captures = try #require(plan.result["recapture"]?["captures"]?.arrayValue)
        #expect(captures.count == 18)
        #expect(captures.allSatisfy { $0["locale"] == "ja" && $0["done"] == false })
        #expect(plan.result["total"]?.intValue == 18)
        let locales = plan.result["locales"]?.arrayValue?.compactMap { $0["locale"]?.stringValue }
        #expect(locales == ["ja"], "None in another language")
        let japanese = plan.result["locales"]?.arrayValue?.first
        #expect(japanese?["testArguments"]?.stringValue?.contains("-testLanguage ja") == true)
        let devices = plan.result["devices"]?.arrayValue?.compactMap { $0["displayType"]?.stringValue }
        #expect(devices == ["iphone", "iphone_duo", "ipad"])
        let iPad = captures.first { $0["displayType"] == "ipad" }
        #expect(iPad?["previousPixelSize"] == "2752 × 2064")
        #expect(iPad?["orientation"] == "landscape")
        #expect(Set(captures.filter { $0["displayType"] == "iphone_duo" }.compactMap { $0["pose"]?.stringValue }) == ["open", "closed"])
        #expect(plan.result["recapture"]?["fromCaptures"]?.stringValue != nil)

        let step = try await fixtures.call(NextStepTool(), [:])
        let asked = step.result["targets"]?.arrayValue ?? step.result["captures"]?.arrayValue ?? []
        #expect(asked.allSatisfy { $0["locale"] == "ja" }, "\(step.result)")
    }

    @Test func withTheSettingOnItOpensAtOnce() async throws {
        let fixtures = Self.fixtures(opens: true)
        let outcome = try await fixtures.call(RequestRecaptureTool(), Self.japanese)

        #expect(outcome.result["status"] == "opened", "\(outcome.result)")
        let run = try #require(fixtures.run)
        #expect(run.isRecapturing)
        #expect(run.recapture?.madeFromCaptures == true)
        #expect(run.totalCaptures == 18)
        #expect(fixtures.center.recaptureRequests(for: Self.appID).isEmpty)
    }

    @Test func aLanguageOrDeviceWithoutCapturesIsRefusedSayingWhatsMissing() async throws {
        let fixtures = Self.fixtures(opens: false)
        let iPad = try await fixtures.call(RequestRecaptureTool(), [
            "targets": [["locale": "fr-FR", "displayType": "ipad"]], "reason": "the phrases were rewritten",
        ])
        #expect(iPad.result["status"] == "refused")
        #expect(iPad.result["reason"]?.stringValue == "Lumen Journal has no captures in fr-FR on ipad.", "\(iPad.result)")

        let korean = try await fixtures.call(RequestRecaptureTool(), ["targets": [["locale": "ko"]], "reason": "rewritten"])
        #expect(korean.result["status"] == "refused")
        #expect(korean.result["reason"]?.stringValue == "Lumen Journal has no captures in ko.")
        #expect(korean.result["reason"]?.stringValue?.contains("Run Autopilot") == false)
    }

    @Test func momentsWithoutARunAreRefusedButTheCapturesAreAskedFor() async throws {
        let fixtures = Self.fixtures(opens: false)
        var arguments = Self.japanese
        arguments["moments"] = ["today-s-phrase-1"]
        let outcome = try await fixtures.call(RequestRecaptureTool(), arguments)

        #expect(outcome.result["status"] == "queued", "\(outcome.result)")
        #expect(outcome.result["captures"]?.intValue == 18)
        #expect(outcome.result["unknownMoments"]?.arrayValue == ["today-s-phrase-1"])
        #expect(outcome.result["momentsReason"]?.stringValue?.contains("no saved Autopilot run") == true)
        #expect(fixtures.center.recaptureRequests(for: Self.appID).first?.momentIDs.isEmpty == true)
    }

    @Test func withNoCapturesAtAllItsRefused() async throws {
        let fixtures = Self.fixtures(opens: true, document: .empty(primary: "en-US"))
        let outcome = try await fixtures.call(RequestRecaptureTool(), Self.japanese)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("has no captures to redo yet") == true)
    }

    @Test func theTextsSayItWorksWithoutASavedRun() {
        #expect(RequestRecaptureTool().definition.description.contains("no saved Autopilot run"))
        #expect(GetCapturePlanTool().definition.description.contains("no Autopilot run was saved"))
        #expect(MCPEndpoint.instructions.contains("no Autopilot run was saved"))
    }

    @Test func getCapturePlanWithoutARunPointsAtRequestRecapture() async throws {
        let fixtures = Self.fixtures(opens: false)
        await #expect {
            _ = try await fixtures.call(GetCapturePlanTool(), [:])
        } throws: { error in
            "\(error)".contains("without a saved run")
        }
    }
}
#endif
