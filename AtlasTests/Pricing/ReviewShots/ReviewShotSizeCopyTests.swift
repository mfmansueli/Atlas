//
//  ReviewShotSizeCopyTests.swift
//  AtlasTests
//

import Foundation
import ImageIO
import Testing
@testable import Atlas

/// The one 640 × 920 copy offered when Apple refuses a review
/// screenshot's dimensions.
@Suite("ReviewShotSizeCopy")
struct ReviewShotSizeCopyTests {
    private let id = "reviewScreenshot.app1.monthly"

    private func change(path: String) -> PendingChange {
        let step = PurchaseReviewScreenshotPush(owner: .subscription, ownerID: "sub", fileName: "paywall.png", fileSize: 1, path: path, checksum: "")
        return PendingChange(
            id: id, appID: "app1", section: .subscriptionPricing, group: "", title: "Monthly", oldValue: "", newValue: "", source: .you,
            requests: [step.request]
        )
    }

    private func refusal(_ text: String, sent: PendingChange, at date: Date = .now) -> PushRecord {
        PushRecord(date: date, appID: "app1", appName: "Lumen", title: "", pushed: [], failures: [id: text], failedChanges: [sent])
    }

    @Test func onlySizeRefusalsCount() {
        #expect(ReviewShotSizeCopy.isAboutSize("App Store Connect couldn’t process “a.png”: The dimensions of the image are incorrect."))
        #expect(ReviewShotSizeCopy.isAboutSize("IMAGE_INCORRECT_DIMENSIONS"))
        #expect(ReviewShotSizeCopy.isAboutSize("Wrong size"))
        #expect(!ReviewShotSizeCopy.isAboutSize("The image couldn't be read."))
    }

    @Test func theCopyIsOfferedOnceForTheRefusedFile() {
        let queued = change(path: "/tmp/big.png")
        let sized = "App Store Connect couldn’t process “paywall.png”: The dimensions of the image are incorrect."
        let records = [refusal(sized, sent: queued)]
        #expect(ReviewShotSizeCopy.offer(for: queued, records: records, pixelSize: PixelSize(width: 1206, height: 2622)) == .copy(details: sized))
        #expect(ReviewShotSizeCopy.offer(for: queued, records: records, pixelSize: ReviewShotSizeCopy.size) == .copyRefused, "Never twice")
        #expect(ReviewShotSizeCopy.offer(for: change(path: "/tmp/other.png"), records: records, pixelSize: nil) == nil, "Replaced since")
        #expect(ReviewShotSizeCopy.offer(for: queued, records: [refusal("The image couldn't be read.", sent: queued)], pixelSize: nil) == nil)
        let later = refusal("Rate limited", sent: queued, at: .now.addingTimeInterval(60))
        #expect(ReviewShotSizeCopy.offer(for: queued, records: records + [later], pixelSize: nil) == nil, "The last refusal decides")
    }

    @Test func theCopyIs640By920WithTheWholeImage() throws {
        let data = EventArtworkTestFiles.png(width: 1206, height: 2622)
        let copy = try ReviewShotResizer.copy(data)
        let source = try #require(CGImageSourceCreateWithData(copy as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 640)
        #expect(image.height == 920)
        let imageSource = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let original = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        let fitted = ReviewShotResizer.fitted(original, in: ReviewShotSizeCopy.size)
        #expect(fitted.height == 920, "Tall: fitted to the height, never cropped")
        #expect(fitted.width < 640)
        #expect(ReviewShotSizeCopy.fileName(from: "paywall.png") == "paywall-640x920.png")
        #expect(throws: ReviewShotResizer.Failure.self) { try ReviewShotResizer.copy(Data("nope".utf8)) }
    }
}
