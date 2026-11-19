//
//  EventArtworkConceptChecksTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// The Check step's four lines: nothing under the text, the text reads,
/// no words in the art (or the name drawn on purpose), and the sizes.
@Suite("Event artwork concept checks")
struct EventArtworkConceptChecksTests {
    private func report(_ kind: InAppEventMedia.Kind, look: InAppEventArtworkLook, size: PixelSize? = nil) -> InAppEventArtworkReport {
        let pixels = size ?? InAppEventArtworkRules.minimumSize(for: kind)
        let file = InAppEventArtworkFile(fileName: "a.png", fileSize: 10, isVideo: false, pixelSize: pixels, colorModel: "RGB")
        return InAppEventArtworkReport(
            fileID: "ea-0000000000", url: URL(filePath: "/tmp/a.png"), kind: kind, file: file, still: nil, posterSeconds: 0, look: look,
            checks: InAppEventArtworkChecker.checks(file, kind: kind, look: look)
        )
    }

    @Test func aCalmDarkPairPassesEverything() {
        let calm = InAppEventArtworkLook(text: [], lowerBusyness: 0.02, lowerBrightness: 0.2)
        let checks = EventArtworkConceptChecks.make([report(.card, look: calm), report(.details, look: calm)], wordsInArt: false)
        #expect(checks.map(\.title) == ["Nothing important under the text", "The text reads on the art", "No words in the art", "Sizes Apple asks for"])
        let allPass = checks.allSatisfy(\.isOK)
        #expect(allPass)
        #expect(checks[3].detail == "1920 × 1080 and 1080 × 1920")
    }

    @Test func busyLightOrWordedArtWarns() {
        let busy = InAppEventArtworkLook(text: ["WINTER"], lowerBusyness: 0.4, lowerBrightness: 0.9)
        let calm = InAppEventArtworkLook(text: [], lowerBusyness: 0.02, lowerBrightness: 0.2)
        let checks = EventArtworkConceptChecks.make([report(.card, look: calm), report(.details, look: busy)], wordsInArt: false)
        #expect(checks.map(\.isOK) == [false, false, false, true])
        #expect(checks[0].detail == "The lower part of the event details is busy where Apple writes the name.")
        #expect(checks[1].detail == "The lower part of the event details is light: Apple’s white text may not read.")
        #expect(checks[2].detail == "Found “WINTER” in the art.")
    }

    @Test func wordsOnPurposeAreNoWarningAndWrongSizesAre() {
        let worded = InAppEventArtworkLook(text: ["Winter"], lowerBusyness: 0.02, lowerBrightness: 0.2)
        let checks = EventArtworkConceptChecks.make([report(.card, look: worded, size: PixelSize(width: 1000, height: 700))], wordsInArt: true)
        #expect(checks[2].title == "The name drawn in each language")
        #expect(checks[2].isOK)
        #expect(!checks[3].isOK)
    }

    @Test func brightnessIsTheLowerPartsMeanLuminance() throws {
        let image = try #require(EventArtworkTestFiles.image(width: 160, height: 90))
        #expect(InAppEventArtworkLook.brightness(of: image) < InAppEventArtworkLook.brightLimit)
    }
}
