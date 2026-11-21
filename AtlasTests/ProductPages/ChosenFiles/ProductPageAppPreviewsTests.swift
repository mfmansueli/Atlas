//
//  ProductPageAppPreviewsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A page's own App Previews: videos chosen with Choose App Previews… are
/// checked (1 to 3, the device's exact size, 15 to 30 seconds), queued as
/// one change per language and device, and pushed into the page's App
/// Preview set like its screenshots.
@MainActor
@Suite("Product page App Previews")
struct ProductPageAppPreviewsTests {
    typealias Sample = DebugProductPagesData

    private static func video(_ name: String, _ width: Int, _ height: Int, seconds: Double = 24) -> ProductPageChosenVideo {
        ProductPageChosenVideo(fileName: name, data: Data(repeating: 7, count: 64), pixelSize: PixelSize(width: width, height: height), seconds: seconds)
    }

    @Test func videosAreCheckedLikeAppleChecksThem() {
        #expect(ProductPageVideoCheck.problems([Self.video("a.mov", 886, 1920), Self.video("b.mp4", 1920, 886)], device: .iPhone).isEmpty)
        let problems = ProductPageVideoCheck.problems([
            Self.video("wide.mov", 1080, 1920), Self.video("short.mov", 886, 1920, seconds: 9),
            ProductPageChosenVideo(fileName: "x.mov", data: Data(), pixelSize: nil, seconds: nil),
        ], device: .iPhone)
        #expect(problems == [
            "“wide.mov” is 1080 × 1920. iPhone 6.9″ takes 886 × 1920, upright or turned.",
            "“short.mov” is 9 seconds long. An App Preview is 15 to 30 seconds.",
            "“x.mov” isn’t a MOV, MP4 or M4V video Atlas can read.",
        ])
        let four = (1...4).map { Self.video("\($0).mov", 1200, 1600) }
        #expect(ProductPageVideoCheck.problems(four, device: .iPad) == ["A set has up to 3 App Previews, and 4 were chosen. Choose 3 or fewer."])
    }

    @Test func chosenVideosWaitInReviewAndPushAsOneChange() async throws {
        let queue = ChangeQueue()
        let model = await ProductPagesTestModel.make(queue: queue)
        let page = try ProductPagesTestModel.page(model, Sample.PageID.mood)
        model.addChosenVideos([Self.video("1.mov", 886, 1920), Self.video("2.mp4", 886, 1920)], for: page, locale: "en-US", folder: .temporary)

        let change = try #require(queue.changes.first)
        #expect(change.id == model.builder.appPreviewsChangeID(pageID: page.id, locale: "en-US", displayType: .iPhone))
        #expect(change.title == "English (U.S.) · App Previews · iPhone")
        #expect(change.newValue == "2 App Previews for this page")
        let push = try #require(change.requests.first.flatMap(ProductPageScreenshotsPush.init))
        #expect(push.media == .appPreviews)
        #expect(push.content.files.map(\.mimeType) == ["video/quicktime", "video/mp4"])
        #expect(model.queuedAppPreviews(of: page, locale: "en-US", device: .iPhone)?.count == 2)
        #expect(model.queuedScreenshots(of: page, locale: "en-US", device: .iPhone) == nil)
        #expect(model.builder.edits(for: page.id, in: queue.changes).appPreviews["en-US"]?[.iPhone]?.count == 2)
        #expect(model.toast?.text == "2 App Previews added to “\(page.name)” in English (U.S.). They’re in Review & Push.")
    }

    @Test func aWrongVideoIsRefusedAndNothingIsQueued() async throws {
        let queue = ChangeQueue()
        let model = await ProductPagesTestModel.make(queue: queue)
        let page = try ProductPagesTestModel.page(model, Sample.PageID.mood)
        model.addChosenVideos([Self.video("1.mov", 1080, 1920)], for: page, locale: "en-US", folder: .temporary)
        #expect(queue.changes.isEmpty)
        #expect(model.filesProblem?.title == "These App Previews can’t go to “\(page.name)”")
    }

    /// The push finds or makes the page's App Preview set (`previewType`
    /// IPHONE_67), reserves each video with its type, and orders them.
    @Test func thePushGoesToTheAppPreviewSet() async throws {
        let transport = FakePageScreenshotsTransport()
        let files = [ProductPageScreenshotsPush.File(path: "/tmp/v/1.mov", fileName: "1.mov", fileSize: 3, checksum: "", mimeType: "video/quicktime")]
        let push = ProductPageScreenshotsPush(.init(
            appID: "lumen", pageID: "page-1", pageName: "Private diary", locale: "en-US", displayType: .iPhone, files: files, media: .appPreviews
        ))
        _ = try await push.send(into: "loc-en", via: transport, readFile: { _ in Data([1, 2, 3]) }, sleep: { _ in })
        #expect(transport.log == [
            "preview sets loc-en IPHONE_67",
            "create appPreviewSets loc-en IPHONE_67",
            "reserve 1.mov set-new video/quicktime", "upload shot-1 0", "commit shot-1",
            "status shot-1",
            "reorder set-new shot-1",
        ])
    }

    /// A screenshots push queued before App Previews (no `media`) still
    /// reads as screenshots.
    @Test func anOlderPushIsScreenshots() throws {
        let body = Data(#"{"productPageScreenshots":{"appID":"a","pageID":"p","pageName":"P","locale":"en-US","displayType":"APP_IPHONE_67","files":[]}}"#.utf8)
        let push = try #require(ProductPageScreenshotsPush(PushRequest(method: .post, path: ProductPageScreenshotsPush.path, body: body)))
        #expect(push.media == .screenshots)
    }
}
