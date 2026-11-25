//
//  ScreenshotTextReadingTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Vision reads the text drawn in an image, and the facts of a screenshot
/// come from what it read.
@MainActor
@Suite("App Review risks · reading screenshots")
struct ScreenshotTextReadingTests {
    @Test(.timeLimit(.minutes(1)))
    func visionReadsFreeInARenderedScreenshot() async throws {
        let image = try #require(ScreenshotTextTestImage.image(["FREE", "Write every day"]))
        let reading = try #require(await ReviewRiskScreenshotReader.reading(of: image, language: "en-US"))
        #expect(reading.texts.contains { $0.localizedCaseInsensitiveContains("free") })
        #expect(reading.lines.allSatisfy { (0...1).contains($0.top) })
        #expect(reading.blankShare != nil)
        #expect(ScreenshotTextRules.findings(in: reading.texts).map(\.kind).contains(.free))
    }

    @Test func aScreenshotsFactsComeFromItsReading() {
        let pick = ReviewRiskScreenshotPick(
            locale: "en-US", displayType: .iPhone, slot: 2,
            screenshot: LiveScreenshot(id: "s2", fileName: "2.png", checksum: "abc", pixelSize: ScreenshotDisplayType.iPhone.defaultPixelSize)
        )
        let reading = ReviewRiskScreenshotReading(
            lines: ["Email", "Password", "Sign In"].map { ReviewRiskScreenshotLine(text: $0, top: 0.5) }, blankShare: 0.2
        )
        let shot = ReviewRiskFactsLoader.screenshot(pick, reading: reading, appName: "Lumen")
        #expect(shot.slot == 2)
        #expect(shot.checksum == "abc")
        #expect(shot.wasRead)
        #expect(!shot.signInLines.isEmpty)
        #expect(!shot.isMostlyBlank)
        #expect(shot.looksOutOfUse)

        let unread = ReviewRiskFactsLoader.screenshot(pick, reading: nil, appName: "Lumen")
        #expect(!unread.wasRead)
        #expect(unread.lines.isEmpty)
    }
}
