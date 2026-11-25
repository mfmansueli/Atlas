//
//  PreviewShotsStripTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The App Store preview's row: the App Preview first, then every
/// screenshot, each tile loading until its image downloads, then the
/// image, or a tile that says there's none.
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
        #expect(strip.isReading)
        #expect(strip.caption(overflows: true) == nil)
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

    @Test func everyIPhoneScreenshotLoadsInItsOwnShape() {
        let live = LiveScreenshots(screenshotSets: [
            set("ipad", locale: "en-US", display: .iPad, count: 5),
            set("iphone", locale: "en-US", count: 5),
        ])
        let strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        let ids = ["iphone.0", "iphone.1", "iphone.2", "iphone.3", "iphone.4"]
        #expect(strip.slots.map(\.id) == ids)
        #expect(strip.pending.map(\.id) == ids)
        #expect(!strip.isReading)
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
        #expect(strip.caption(overflows: false) == "3 screenshots")
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

    @Test func screenshotsDecodedBeforeShowAtOnce() throws {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 3)])
        let kept = try image(width: 10, height: 20)
        var strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        strip.finishKept { $0.id == "iphone.1" ? nil : kept }
        #expect(strip.slots.map { $0.phase.image != nil } == [true, false, true])
        #expect(strip.pending.map(\.id) == ["iphone.1"])
        #expect(strip.isLoading)
    }

    // MARK: - App Preview first

    private func previews(locale: String, display: ScreenshotDisplayType = .iPhone, seconds: Int? = nil) -> LiveAppPreviewSet {
        LiveAppPreviewSet(
            id: "previews.\(locale)", locale: locale, displayType: display, previewCount: 1, durationSeconds: seconds,
            previews: [LiveAppPreview(
                id: "preview.\(locale)", fileName: "Lumen.mov", posterURLTemplate: "https://example.com/{w}x{h}.{f}",
                posterPixelSize: PixelSize(width: 886, height: 1920)
            )]
        )
    }

    @Test func theAppPreviewComesBeforeEveryScreenshot() {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 5)], previewSets: [previews(locale: "en-US", seconds: 28)])
        let strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        #expect(strip.items.map(\.isAppPreview) == [true, false, false, false, false, false])
        #expect(strip.items.first?.id == "appPreview.preview.en-US")
        #expect(strip.appPreviews.first?.lengthTitle == "0:28")
        #expect(strip.appPreviews.first?.displayType == .iPhone)
        #expect(abs((strip.appPreviews.first?.aspect ?? 0) - 1920.0 / 886.0) < 0.001)
        #expect(strip.caption(overflows: true) == "App Preview and 5 screenshots · scroll for more")
        #expect(strip.caption(overflows: false) == "App Preview and 5 screenshots")
    }

    @Test func theAppPreviewOfAnotherDeviceIsntShown() {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 2)], previewSets: [previews(locale: "en-US", display: .iPad)])
        let strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        #expect(strip.appPreviews.isEmpty)
        #expect(strip.caption(overflows: false) == "2 screenshots")
    }

    @Test func aBorrowedRowBorrowsTheAppPreviewToo() {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 3)], previewSets: [previews(locale: "en-US")])
        let strip = PreviewShotsStrip(live: live, locale: german, primary: english)
        #expect(strip.appPreviews.map(\.locale) == ["en-US"])
    }

    @Test func thePosterAndLengthArriveOnTheirOwn() throws {
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 1)], previewSets: [previews(locale: "en-US")])
        var strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        #expect(strip.pendingPosters.map(\.id) == ["preview.en-US"])
        #expect(strip.appPreviews[0].lengthTitle == nil)
        #expect(strip.appPreviews[0].accessibilityLabel == "App Preview")
        try strip.finish("iphone.0", with: image(width: 252, height: 546))
        #expect(strip.isLoading)
        try strip.finishPoster("preview.en-US", with: image(width: 100, height: 200))
        strip.setSeconds(65, for: "preview.en-US")
        #expect(strip.pendingPosters.isEmpty)
        #expect(!strip.isLoading)
        #expect(strip.appPreviews[0].lengthTitle == "1:05")
        #expect(strip.appPreviews[0].accessibilityLabel == "App Preview, 1:05")
        #expect(strip.accessibilityLabel == "App Preview and 1 screenshot")
    }

    @Test func aSetReadBeforePreviewsWereKeptStillCountsThem() {
        let old = LiveAppPreviewSet(id: "old", locale: "en-US", displayType: .iPhone, previewCount: 2)
        let live = LiveScreenshots(screenshotSets: [set("iphone", locale: "en-US", count: 1)], previewSets: [old])
        let strip = PreviewShotsStrip(live: live, locale: english, primary: english)
        #expect(strip.appPreviews.map(\.id) == ["old.0", "old.1"])
        #expect(strip.pendingPosters.isEmpty)
        #expect(strip.caption(overflows: false) == "2 App Previews and 1 screenshot")
    }
}
