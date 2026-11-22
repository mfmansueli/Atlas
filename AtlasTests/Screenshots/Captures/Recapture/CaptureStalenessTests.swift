//
//  CaptureStalenessTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Captures marked out of date, and Replace…'s size check.
@Suite("Capture staleness and replacement")
struct CaptureStalenessTests {
    private let staleness = CaptureStaleness(reason: "phrases rewritten", evidence: "d038b58", client: "Claude Code", markedAt: .distantPast)

    private func capture(_ locale: String, slot: Int, id: String) -> ScreenshotCapture {
        ScreenshotCapture(
            id: id, locale: locale, displayType: .iPhone, slot: slot, source: .autopilot, fileName: "\(id).png",
            pixelSize: ScreenshotDisplayType.iPhone.portraitPixelSize, importedAt: .distantPast
        )
    }

    @Test func markingTouchesOnlyThatLanguagesOwnCapture() {
        var index = CaptureIndex()
        index.add(capture("en-US", slot: 0, id: "en-0"))
        index.add(capture("ja", slot: 0, id: "ja-0"))
        index.add(capture("ja", slot: 1, id: "ja-1"))

        let markedJapanese = index.markStale(locale: "ja", displayType: .iPhone, slot: 0, as: staleness)
        let markedFrench = index.markStale(locale: "fr-FR", displayType: .iPhone, slot: 0, as: staleness)
        #expect(markedJapanese)
        #expect(!markedFrench, "fr-FR has none of its own")
        #expect(index.staleCaptures.map(\.id) == ["ja-0"])
    }

    @Test func aNewCaptureInItsPlaceIsntOutOfDate() {
        var index = CaptureIndex()
        index.add(capture("ja", slot: 0, id: "ja-0"))
        index.markStale(locale: "ja", displayType: .iPhone, slot: 0, as: staleness)
        index.add(capture("ja", slot: 0, id: "ja-0-new"))
        #expect(index.staleCaptures.isEmpty)
    }

    @Test func staleCapturesSurviveBeingSaved() throws {
        var item = capture("ja", slot: 0, id: "ja-0")
        item.stale = staleness
        let decoded = try JSONDecoder().decode(ScreenshotCapture.self, from: JSONEncoder().encode(item))
        #expect(decoded.stale == staleness)
    }

    @Test func replaceTakesAFullSizeScreenshotOfTheDevice() {
        #expect(CaptureReplacement.refusal(size: ScreenshotDisplayType.iPhone.portraitPixelSize, for: .iPhone) == nil)
        #expect(CaptureReplacement.refusal(size: ScreenshotDisplayType.iPad.portraitPixelSize, for: .iPhone) != nil, "An iPad screenshot")
        #expect(CaptureReplacement.refusal(size: PixelSize(width: 300, height: 650), for: .iPhone) != nil, "Too small")
        #expect(CaptureReplacement.refusal(size: nil, for: .iPhone) != nil)
    }

    @Test func replaceMakesAnImportItemForTheCell() {
        let cell = CaptureCellKey(locale: "ja", displayType: .iPhone, slot: 2)
        let size = ScreenshotDisplayType.iPhone.portraitPixelSize
        let item = CaptureReplacement.item(URL(filePath: "/tmp/Today.png"), size: size, in: cell)
        #expect(item.placement == CaptureMatchRow.Placement(locale: "ja", displayType: .iPhone, slot: 2))
        #expect(item.candidate.path == "Today.png")
        #expect(item.candidate.pixelSize == size)
    }
}
#endif
