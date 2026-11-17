//
//  InAppEventArtworkFilesTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Where event art waits on this Mac, and reading what a file is: an
/// image's size, alpha and color model, a video's size, frame rate,
/// length and codec, and how busy the lower part is.
@Suite("In-App Event artwork files")
struct InAppEventArtworkFilesTests {
    private let directory = EventArtworkTestFiles.directory()

    @Test func aFileKeepsItsNameUnderItsID() throws {
        let id = try InAppEventArtworkFiles.save(Data([0x89, 0x50, 0x4E, 0x47, 1, 2]), fileName: "Gratitude card.png", appID: "42", in: directory)
        #expect(InAppEventArtworkFiles.isFileID(id))
        let url = try #require(InAppEventArtworkFiles.url(id: id, appID: "42", in: directory))
        #expect(url.lastPathComponent == "Gratitude card.png")
        #expect(url.deletingLastPathComponent().lastPathComponent == id)
        // Another app's, or a path, isn't found.
        #expect(InAppEventArtworkFiles.url(id: id, appID: "43", in: directory) == nil)
        #expect(InAppEventArtworkFiles.url(id: "../../etc", appID: "42", in: directory) == nil)
    }

    @Test func aNameWithoutAnExtensionGetsTheBytesOne() {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0, 0, 0])
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0])
        let mov = Data([0, 0, 0, 20] + Array("ftypqt  ".utf8))
        let mp4 = Data([0, 0, 0, 20] + Array("ftypisom".utf8))
        #expect(InAppEventArtworkFiles.name("card", for: png) == "card.png")
        #expect(InAppEventArtworkFiles.name(nil, for: jpeg) == "event-artwork.jpg")
        #expect(InAppEventArtworkFiles.name("../../loop", for: mov) == "loop.mov")
        #expect(InAppEventArtworkFiles.name("a:b", for: mp4) == "a-b.mp4")
        #expect(InAppEventArtworkFiles.name("card.png", for: jpeg) == "card.png")
        #expect(InAppEventArtworkFiles.sniffedExtension(Data("hello".utf8)) == nil)
        #expect(InAppEventArtworkFiles.renderedName(event: "Gratitude Week 2026", kind: .card, locale: "en-US") == "gratitude-week-2026-card-en-us.png")
    }

    @Test func anImageIsReadWithItsSizeAlphaAndColorModel() async throws {
        let id = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080, alpha: true), name: "card.png", in: directory)
        let url = try #require(InAppEventArtworkFiles.url(id: id, appID: InAppEventsTestData.app.id, in: directory))
        let file = try #require(await InAppEventArtworkInspector.inspect(url))
        #expect(file.isVideo == false)
        #expect(file.pixelSize == PixelSize(width: 1920, height: 1080))
        #expect(file.hasAlpha)
        #expect(file.colorModel == "RGB")
        #expect(file.fileName == "card.png")

        let jpegID = try EventArtworkTestFiles.store(EventArtworkTestFiles.jpeg(width: 1080, height: 1920), name: "details.jpg", in: directory)
        let jpegURL = try #require(InAppEventArtworkFiles.url(id: jpegID, appID: InAppEventsTestData.app.id, in: directory))
        let jpeg = try #require(await InAppEventArtworkInspector.inspect(jpegURL))
        #expect(jpeg.pixelSize == PixelSize(width: 1080, height: 1920))
        #expect(!jpeg.hasAlpha)
    }

    @Test func aVideoIsReadWithItsFrameRateLengthAndCodec() async throws {
        let url = try await EventArtworkTestFiles.movie(width: 1920, height: 1080, fps: 30, frames: 15, in: directory)
        let file = try #require(await InAppEventArtworkInspector.inspect(url))
        #expect(file.isVideo)
        #expect(file.pixelSize == PixelSize(width: 1920, height: 1080))
        #expect(abs((file.frameRate ?? 0) - 30) < 0.5)
        #expect(abs((file.seconds ?? 0) - 0.5) < 0.1)
        #expect(file.codec == "avc1")
        #expect(file.audio.isEmpty)
        #expect(await InAppEventArtworkInspector.still(url, isVideo: true, at: 0.2) != nil)
        #expect(InAppEventArtworkChecker.checks(file, kind: .card, look: nil).filter(\.isRefusal).isEmpty)

        let slow = try await EventArtworkTestFiles.movie(width: 1920, height: 1080, fps: 24, frames: 12, in: directory, name: "slow.mov")
        let slowFile = try #require(await InAppEventArtworkInspector.inspect(slow))
        #expect(InAppEventArtworkChecker.checks(slowFile, kind: .card, look: nil).first?.text.contains("runs at 24 fps") == true)
    }

    @Test func aCalmLowerPartIsntBusyAndAFineOneIs() throws {
        let calm = try #require(EventArtworkTestFiles.image(width: 960, height: 540))
        let busy = try #require(EventArtworkTestFiles.image(width: 960, height: 540, busy: true))
        #expect(InAppEventArtworkLook.busyness(of: calm) < 0.01)
        let busyness = InAppEventArtworkLook.busyness(of: busy)
        #expect(busyness > InAppEventArtworkLook.busyLimit)
        #expect(InAppEventArtworkLook(lowerBusyness: busyness).isLowerPartBusy)
    }

    @Test func aReportTurnsAFileIntoChecksAndAPosterFrame() async throws {
        let id = try await EventArtworkTestFiles.storedMovie(width: 1080, height: 1920, fps: 60, frames: 90, in: directory)
        let report = try #require(await InAppEventArtworkReport.make(
            fileID: id, appID: InAppEventsTestData.app.id, kind: .details, language: "en-US", posterSeconds: 1, in: directory
        ))
        #expect(report.canQueue)
        #expect(report.previewFrameTimeCode == "00:00:01:00")
        #expect(report.still != nil)
        #expect(report.json["canPropose"] == true)
        #expect(report.json["kind"] == "details")
        #expect(report.json["audio"] == "none")
        let missing = await InAppEventArtworkReport.make(
            fileID: "ea-0000000000", appID: InAppEventsTestData.app.id, kind: .card, language: "en-US", in: directory
        )
        #expect(missing == nil)
    }
}
