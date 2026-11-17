//
//  PreviewShotsStripTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The App Store preview's screenshot strip: every tile loading until its
/// screenshot downloads, then the image, or a tile that says there's none.
@MainActor
@Suite("PreviewShotsStrip")
struct PreviewShotsStripTests {
    private let english = StoreLocaleCatalog.locale(code: "en-US")!
    private let german = StoreLocaleCatalog.locale(code: "de-DE")!

    private func shot(_ id: String, width: Int = 1290, height: Int = 2796) -> LiveScreenshot {
        LiveScreenshot(id: id, fileName: "\(id).png", pixelSize: PixelSize(width: width, height: height))
    }

    private func set(_ id: String, locale: String, display: ScreenshotDisplayType = .iPhone, count: Int) -> LiveScreenshotSet {
        LiveScreenshotSet(id: id, locale: locale, displayType: display, screenshots: (0..<count).map { shot("\(id).\($0)") })
    }

    private func image(width: Int, height: Int) throws -> CGImage {
        try #require(FakeScreenshotsServices.flatImage(width: width, height: height))
    }

    @Test func whileTheScreenshotsAreReadEveryTileIsLoading() {
        let strip = PreviewShotsStrip.reading
        #expect(strip.slots.count == 3)
        #expect(strip.slots.allSatisfy { $0.phase.isLoading && $0.isPlaceholder })
        #expect(strip.isLoading)
        #expect(strip.pending.isEmpty)
        #expect(strip.accessibilityLabel == "Loading screenshots")
    }

    @Test func screenshotsThatCantBeReadStopLoading() {
        let strip = PreviewShotsStrip.unreadable
        #expect(strip.slots.count == 3)
        #expect(!strip.isLoading)
        #expect(strip.isUnreadable)
        #expect(strip.accessibilityLabel == "Screenshots couldn’t be read")
    }

    @Test func theFirstThreeIPhoneScreenshotsLoadInTheirOwnShape() {
        let live = LiveScreenshots(screenshotSets: [
            set("ipad", locale: "en-US", display: .iPad, count: 5),
            set("iphone", locale: "en-US", count: 5),
        ])
        let strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        #expect(strip.slots.map(\.id) == ["iphone.0", "iphone.1", "iphone.2"])
        #expect(strip.pending.map(\.id) == ["iphone.0", "iphone.1", "iphone.2"])
        #expect(strip.slots.allSatisfy { $0.phase.isLoading && !$0.isPlaceholder })
        #expect(abs(strip.slots[0].aspect - 2796.0 / 1290.0) < 0.001)
        #expect(!strip.isBorrowed)
        #expect(strip.accessibilityLabel == "Loading screenshots")
    }

    @Test func eachScreenshotShowsAsSoonAsItArrives() throws {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 3)])
        var strip = PreviewShotsStrip(live: live, locale: english, primary: english)

        try strip.finish("iphone.1", with: image(width: 252, height: 546))
        #expect(strip.slots[0].phase.isLoading)
        #expect(strip.slots[1].phase.image != nil)
        #expect(strip.slots[2].phase.isLoading)
        #expect(strip.pending.map(\.id) == ["iphone.0", "iphone.2"])
        #expect(strip.isLoading)

        try strip.finish("iphone.0", with: image(width: 252, height: 546))
        try strip.finish("iphone.2", with: image(width: 252, height: 546))
        #expect(!strip.isLoading)
        #expect(strip.accessibilityLabel == "3 screenshots")
    }

    @Test func aScreenshotThatCantBeDownloadedStopsLoading() throws {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 2)])
        var strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        try strip.finish("iphone.0", with: image(width: 252, height: 546))
        strip.finish("iphone.1", with: nil)
        #expect(!strip.isLoading)
        #expect(!strip.slots[1].isPlaceholder)
        #expect(strip.slots[1].phase.image == nil)
        #expect(strip.accessibilityLabel == "1 of 2 screenshots shown")
    }

    /// Without a pixel size from App Store Connect, the tile starts as an
    /// iPhone screenshot and takes the image's shape once it's here.
    @Test func aTileTakesTheImagesShapeWhenTheSizeWasUnknown() throws {
        let unsized = LiveScreenshot(id: "mac.0", fileName: "mac.png")
        let live = LiveScreenshots(screenshotSets: [LiveScreenshotSet(id: "mac", locale: "en-US", displayType: .mac, screenshots: [unsized])])
        var strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        #expect(strip.slots[0].aspect == PreviewShotsStrip.placeholderAspect)
        try strip.finish("mac.0", with: image(width: 288, height: 180))
        #expect(abs(strip.slots[0].aspect - 0.625) < 0.001)
    }

    @Test func aFinishedOrUnknownScreenshotIsLeftAlone() throws {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 1)])
        var strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        try strip.finish("iphone.0", with: image(width: 252, height: 546))
        strip.finish("iphone.0", with: nil)
        strip.finish("elsewhere", with: nil)
        #expect(strip.slots[0].phase.image != nil)
        #expect(strip.slots.count == 1)
    }

    @Test func aLanguageWithoutScreenshotsBorrowsThePrimarysAndSaysSo() {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 3)])
        let strip = PreviewShotsStrip(live: live, locale: german, primary: english)
        #expect(strip.isBorrowed)
        #expect(strip.slots.map(\.id) == ["iphone.0", "iphone.1", "iphone.2"])
    }

    @Test func noScreenshotsAtAllShowsPlainTiles() {
        let strip = PreviewShotsStrip(live: LiveScreenshots(), locale: german, primary: english)
        #expect(strip.slots.count == 3)
        #expect(strip.slots.allSatisfy { $0.isPlaceholder && !$0.phase.isLoading })
        #expect(strip.pending.isEmpty)
        #expect(!strip.isBorrowed)
        #expect(strip.accessibilityLabel == "No screenshots yet")
    }

    @Test func anEmptySetIsSkipped() {
        let live = LiveScreenshots(screenshotSets: [
            set("empty", locale: "en-US", count: 0),
            set("ipad", locale: "en-US", display: .iPad, count: 2),
        ])
        #expect(PreviewShotsStrip.bestSet(in: live, locale: english)?.id == "ipad")
    }
}
