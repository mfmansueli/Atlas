//
//  ReviewShotsCaptureFinderTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Screenshots capture a product missing its review screenshot can
/// use: the paywall screen's, in the plan's primary language, on iPhone
/// first, best scored and newest.
@MainActor
@Suite("ReviewShotsCaptureFinder")
struct ReviewShotsCaptureFinderTests {
    private typealias Fixtures = AutopilotTestFixtures

    private func run(screens: [AutopilotScreen]) -> AutopilotRun {
        let plan = AutopilotPlan(screens: screens, displayTypes: [.iPhone, .iPad], localeCodes: ["en-US", "de-DE"], primaryLocale: "en-US")
        return Fixtures.run(.capture, plan: plan)
    }

    @Test func thePaywallIsKnownByItsName() {
        for name in ["Paywall", "Lumen Plus", "Go Premium", "Upgrade", "Subscription plans", "Unlock everything"] {
            #expect(ReviewShotsCaptureFinder.isPaywall(AutopilotScreen(name: name, steps: "")), "\(name)")
        }
        for name in ["Today", "Settings", "Journal entry", "Profile"] {
            #expect(!ReviewShotsCaptureFinder.isPaywall(AutopilotScreen(name: name, steps: "")), "\(name)")
        }
    }

    @Test func noPaywallScreenNoCapture() {
        var run = run(screens: [AutopilotScreen(name: "Today", steps: "")])
        Fixtures.captureAll(&run)
        #expect(ReviewShotsCaptureFinder.find(in: run) == nil)
        #expect(ReviewShotsCaptureFinder.find(in: nil) == nil)
    }

    @Test func itPicksTheIPhoneCaptureInThePrimaryLanguage() throws {
        var run = run(screens: [AutopilotScreen(name: "Today", steps: ""), AutopilotScreen(name: "Paywall", steps: "")])
        let paywall = try #require(run.plan.screens.last)
        run.captures = [
            Fixtures.capture(Fixtures.target(paywall.id, .iPad, "en-US"), score: 1),
            Fixtures.capture(Fixtures.target(paywall.id, .iPhone, "de-DE"), score: 1),
            Fixtures.capture(Fixtures.target(paywall.id, .iPhone, "en-US"), score: 0.6, second: 1),
            Fixtures.capture(Fixtures.target(paywall.id, .iPhone, "en-US"), attempt: 2, score: 0.9, second: 2),
        ]
        let capture = try #require(ReviewShotsCaptureFinder.find(in: run))
        #expect(capture.captureID == "png-\(paywall.id)-\(ScreenshotDisplayType.iPhone.mcpValue)-en-US-2")
        #expect(capture.number == 2)
        #expect(capture.title == "Capture 2 · Paywall")
        #expect(capture.displayType == .iPhone)
        #expect(capture.url(appID: "app1", root: URL(filePath: "/tmp/r")).path(percentEncoded: false) == "/tmp/r/app1/Captures/\(capture.captureID).png")
    }
}
#endif
