//
//  LiveScreenshotTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A live screenshot's image: its URL from App Store Connect's template,
/// and why there's none when its upload is unfinished, failed or still
/// processing.
@MainActor
@Suite("LiveScreenshot")
struct LiveScreenshotTests {
    private static let processed = LiveScreenshot(
        id: "s1", fileName: "one.png", checksum: "c1", pixelSize: PixelSize(width: 1320, height: 2868),
        imageURLTemplate: "https://example.invalid/s1/{w}x{h}bb.{f}", deliveryState: ScreenshotDeliveryState(state: "COMPLETE")
    )

    private static func withoutImage(_ state: String?) -> LiveScreenshot {
        LiveScreenshot(id: "s2", fileName: "two.png", deliveryState: state.map { ScreenshotDeliveryState(state: $0) })
    }

    @Test func aProcessedScreenshotHasItsImage() {
        #expect(Self.processed.missingImage == nil)
        #expect(Self.processed.imageURL(width: 660)?.absoluteString == "https://example.invalid/s1/660x1434bb.png")
    }

    @Test func oneStillProcessingHasNoImageYet() {
        #expect(Self.withoutImage("UPLOAD_COMPLETE").missingImage == .stillProcessing)
    }

    @Test func anUnfinishedOrFailedUploadHasNoImageAtAll() {
        #expect(Self.withoutImage("AWAITING_UPLOAD").missingImage == .noImage)
        #expect(Self.withoutImage("FAILED").missingImage == .noImage)
        #expect(Self.withoutImage(nil).missingImage == .noImage)
    }

    @Test func thePushDoesntDownloadAScreenshotWithNoImage() async {
        let transport = FakeHTTPTransport([])
        let services = LiveScreenshotPushServices(client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport))
        await #expect(throws: LiveScreenshotImageError.noImage) { try await services.liveImageData(Self.withoutImage("FAILED")) }
        await #expect(throws: LiveScreenshotImageError.stillProcessing) { try await services.liveImageData(Self.withoutImage("UPLOAD_COMPLETE")) }
        #expect(transport.requests.isEmpty)
    }

    @Test func aReplacedScreenshotIsKeptFromTheImageCache() async throws {
        let server = RemoteImageTestServer()
        let transport = FakeHTTPTransport([])
        var services = LiveScreenshotPushServices(client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport))
        services.images = RemoteImageCache(directory: nil, fetch: server.fetch)
        let shot = Self.processed
        let url = try #require(shot.imageURL(width: shot.pixelSize?.width ?? 0))
        // Seen before in the Studio: the backup reads it without a download.
        _ = try await services.images.data(for: url)
        let data = try await services.liveImageData(shot)
        #expect(!data.isEmpty)
        #expect(server.downloads(of: url) == 1)
        #expect(transport.requests.isEmpty)
    }
}
