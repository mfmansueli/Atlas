//
//  ImageLoadPhaseTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Atlas

/// Where an image a view loads has got to: loading until its load has
/// finished, then the image, or nothing to show.
@MainActor
@Suite("ImageLoadPhase")
struct ImageLoadPhaseTests {
    private let icon = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/icon/512x512bb.png")!
    private let otherIcon = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/other/512x512bb.png")!

    private func image() throws -> CGImage {
        try #require(FakeScreenshotsServices.flatImage(width: 4, height: 4))
    }

    @Test func aFinishedLoadIsTheImageOrNothing() throws {
        let loaded = try ImageLoadPhase(finished: image())
        #expect(loaded.image?.width == 4)
        #expect(!loaded.isLoading)

        let missing = ImageLoadPhase(finished: nil)
        #expect(missing.image == nil)
        #expect(!missing.isLoading)

        #expect(ImageLoadPhase.loading.isLoading)
        #expect(ImageLoadPhase.loading.image == nil)
    }

    @Test func anAppIconLoadsUntilItsDownloadFinishes() {
        typealias Icon = RemoteAppIconImage<EmptyView>
        #expect(Icon.phase(image: nil, cached: nil, finishedURL: nil, url: icon).isLoading)
        // Another icon's download finishing doesn't end this one's.
        #expect(Icon.phase(image: nil, cached: nil, finishedURL: otherIcon, url: icon).isLoading)
        let failed = Icon.phase(image: nil, cached: nil, finishedURL: icon, url: icon)
        #expect(!failed.isLoading && failed.image == nil)
    }

    @Test func aCachedAppIconShowsStraightAway() throws {
        typealias Icon = RemoteAppIconImage<EmptyView>
        #expect(try Icon.phase(image: nil, cached: image(), finishedURL: nil, url: icon).image != nil)
        #expect(try Icon.phase(image: image(), cached: nil, finishedURL: icon, url: icon).image != nil)
    }

    @Test func anExtrasThumbnailLoadsWhileItsPNGIsRead() {
        let png = URL(fileURLWithPath: "/tmp/header-en-US.png")
        let movie = URL(fileURLWithPath: "/tmp/preview-en-US.mov")
        #expect(ExtrasFileThumbnail.isReading(png, readURL: nil))
        #expect(ExtrasFileThumbnail.isReading(png, readURL: URL(fileURLWithPath: "/tmp/search-en-US.png")))
        #expect(!ExtrasFileThumbnail.isReading(png, readURL: png))
        // A movie or a missing file has nothing to read.
        #expect(!ExtrasFileThumbnail.isReading(movie, readURL: nil))
        #expect(!ExtrasFileThumbnail.isReading(nil, readURL: nil))
    }
}
