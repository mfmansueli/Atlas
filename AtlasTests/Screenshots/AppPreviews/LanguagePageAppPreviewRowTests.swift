//
//  LanguagePageAppPreviewRowTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The App Previews the Screenshots language page's row starts with, as on
/// the App Store: on every device that has them (a Mac app's too), the set
/// waiting in Review & Push when there's one, else what's live, and the
/// line above the row counting them.
@MainActor
@Suite("Language page App Previews")
struct LanguagePageAppPreviewRowTests {
    private static let movie = URL(string: "https://example.com/preview.m3u8")!

    private static func macSet(locale: String = "en-US") -> LiveAppPreviewSet {
        LiveAppPreviewSet(
            id: "mac-set", locale: locale, displayType: .mac, previewCount: 1,
            previews: [LiveAppPreview(
                id: "mac-1", fileName: "SimProps.mov", posterURLTemplate: "https://example.com/{w}x{h}.{f}",
                posterPixelSize: PixelSize(width: 1920, height: 1080), videoURL: movie
            )]
        )
    }

    private static func iPhoneSet(_ ids: [String]) -> LiveAppPreviewSet {
        LiveAppPreviewSet(
            id: "set", locale: "ja", displayType: .iPhone, previewCount: ids.count,
            previews: ids.map { LiveAppPreview(id: $0, fileName: "\($0).mov") }
        )
    }

    // MARK: - The row

    @Test func aMacAppsLiveAppPreviewStartsTheRow() throws {
        let items = LanguagePageAppPreviewRow.items(queued: nil, live: Self.macSet(), locale: "en-US", displayType: .mac)
        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.id == "mac-1")
        #expect(item.position == 0)
        #expect(item.count == 1)
        #expect(item.live?.id == "mac-1")
        #expect(!item.isPending)
        #expect(item.stateTitle == "Live")
        #expect(item.movieURL == Self.movie)
        #expect(abs(item.aspect - 1080.0 / 1920.0) < 0.001)
        #expect(item.pixelSize == PixelSize(width: 1920, height: 1080))
    }

    @Test func aSetReadBeforeEachPreviewWasKeptStillShowsOneTilePerPreview() {
        let live = LiveAppPreviewSet(id: "old", locale: "en-US", displayType: .mac, previewCount: 2, previews: nil)
        let items = LanguagePageAppPreviewRow.items(queued: nil, live: live, locale: "en-US", displayType: .mac)
        #expect(items.map(\.id) == ["old.0", "old.1"])
        #expect(items.allSatisfy { $0.live == nil && $0.movieURL == nil && $0.count == 2 })
        #expect(items.allSatisfy { abs($0.aspect - 1080.0 / 1920.0) < 0.001 })
    }

    @Test func noLiveSetMeansNoAppPreviewInTheRow() {
        #expect(LanguagePageAppPreviewRow.items(queued: nil, live: nil, locale: "en-US", displayType: .mac).isEmpty)
    }

    @Test func aChangeWaitingInReviewAndPushShowsTheSetAsItEnds() throws {
        let live = Self.iPhoneSet(["a", "b"])
        var content = AppPreviewSetPush.Content.start(appID: "lumen", localizationID: "loc-ja", locale: "ja", displayType: .iPhone, live: live)
        content.replace(
            at: 0,
            with: ProductPageScreenshotsPush.File(path: "/tmp/new.mov", fileName: "new.mov", fileSize: 1, checksum: "", mimeType: "video/quicktime")
        )
        let items = LanguagePageAppPreviewRow.items(queued: content, live: live, locale: "ja", displayType: .iPhone)
        #expect(items.count == 2)
        let first = try #require(items.first)
        #expect(first.isPending)
        #expect(first.stateTitle == "Not pushed")
        #expect(first.fileURL == URL(fileURLWithPath: "/tmp/new.mov"))
        #expect(first.movieURL == URL(fileURLWithPath: "/tmp/new.mov"))
        #expect(first.live == nil)
        #expect(items[1].live?.id == "b")
        #expect(items[1].stateTitle == "Live")
    }

    @Test func eachDeviceHasItsAppPreviewsShape() {
        #expect(abs(LanguagePageAppPreviewRow.aspect(of: .iPhone) - 1920.0 / 886.0) < 0.001)
        #expect(abs(LanguagePageAppPreviewRow.aspect(of: .iPad) - 1600.0 / 1200.0) < 0.001)
        #expect(abs(LanguagePageAppPreviewRow.aspect(of: .mac) - 1080.0 / 1920.0) < 0.001)
        #expect(abs(LanguagePageAppPreviewRow.aspect(of: .visionPro) - 1080.0 / 1920.0) < 0.001)
    }

    // MARK: - The line above the row

    @Test func theLineCountsTheAppPreviewAndTheScreenshots() {
        let one = ScreenshotHandDeviceLine.text(device: "Mac", size: "2880 × 1800", screenshots: 6, capacity: 10, appPreviews: 1)
        #expect(one.hasPrefix("Mac · 2880 × 1800 · App Preview and 6 of 10 screenshots. Select a screenshot"))
        let two = ScreenshotHandDeviceLine.text(device: "iPhone 6.9″", size: "1320 × 2868", screenshots: 4, capacity: 10, appPreviews: 2)
        #expect(two.hasPrefix("iPhone 6.9″ · 1320 × 2868 · 2 App Previews and 4 of 10 screenshots."))
    }

    @Test func withoutAppPreviewsTheLineStaysAsItWas() {
        let line = ScreenshotHandDeviceLine.text(device: "Mac", size: "2880 × 1800", screenshots: 6, capacity: 10, appPreviews: 0)
        #expect(line == "Mac · 2880 × 1800 · 6 of 10. Select a screenshot to replace, move or delete it, or drop files to add them.")
    }

    // MARK: - The view model

    @Test func theMacPageListsTheMacAppPreviewInNowAndSuggested() async {
        var live = ScreenshotsDebugDocuments.live
        live.previewSets.append(Self.macSet())
        let services = FakeScreenshotsServices(document: ScreenshotsDebugDocuments.standard, live: live)
        let context = ScreenshotsContext(primaryLocale: .englishUS, version: ScreenshotsTestFixtures.editableVersion, localizations: [.englishUS: "loc-en"])
        let model = ScreenshotsViewModel(app: ScreenshotsTestFixtures.app, services: services, context: context)
        await model.load()
        model.renderQueue.cancel()
        let queue = ChangeQueue()

        model.showsSuggestedCaptions = false
        #expect(model.pageAppPreviews(locale: "en-US", displayType: .mac, queue: queue).map(\.id) == ["mac-1"])
        model.showsSuggestedCaptions = true
        #expect(model.pageAppPreviews(locale: "en-US", displayType: .mac, queue: queue).map(\.id) == ["mac-1"])
        // iPhone keeps its own App Preview; a language without any has none.
        #expect(model.pageAppPreviews(locale: "en-US", displayType: .iPhone, queue: queue).map(\.id) == ["preview|en-US|0"])
        #expect(model.pageAppPreviews(locale: "de-DE", displayType: .mac, queue: queue).isEmpty)
        #expect(model.handDeviceLine(locale: "en-US", displayType: .mac, appPreviews: 1).contains("App Preview and"))
    }
}
#endif
