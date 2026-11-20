//
//  ProductPageScreenshotsPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing a custom product page's own screenshots of one language and
/// device (board 52): the localization's set of that device is found or
/// made, each PNG reserved, uploaded and committed with its MD5, Apple's
/// processing waited for, the old ones deleted and the new ones put in
/// order. A set takes 10, so the old ones go first when both wouldn't fit.
@MainActor
@Suite("Product page screenshots push")
struct ProductPageScreenshotsPushTests {
    private static let files: [String: Data] = [
        "/tmp/page/1.png": Data((0..<120).map { UInt8($0) }),
        "/tmp/page/2.png": Data((0..<80).map { UInt8(255 - $0) }),
    ]

    private static func push(count: Int = 2, pageID: String = "page-1", display: ScreenshotDisplayType = .iPhone) -> ProductPageScreenshotsPush {
        let files = (1...count).map { number in
            ProductPageScreenshotsPush.File(path: "/tmp/page/\((number - 1) % 2 + 1).png", fileName: "\(number).png", fileSize: 100, checksum: "")
        }
        return ProductPageScreenshotsPush(.init(
            appID: "lumen", pageID: pageID, pageName: "Private diary", currentDeepLink: "https://lumen.app/lock", locale: "en-US",
            displayType: display, files: files
        ))
    }

    private static func send(_ push: ProductPageScreenshotsPush, via transport: FakePageScreenshotsTransport) async throws -> String {
        try await push.send(into: "loc-en", via: transport, readFile: { path in
            guard let data = files[path] else { throw CocoaError(.fileNoSuchFile) }
            return data
        }, sleep: { _ in })
    }

    @Test func aPageWithoutASetGetsOneAndTheScreenshotsInOrder() async throws {
        let transport = FakePageScreenshotsTransport()
        var processing = 0
        let id = try await Self.push().send(
            into: "loc-en", via: transport, readFile: { Self.files[$0] ?? Data() }, sleep: { _ in }, processing: { processing += 1 }
        )

        #expect(id == "set-new")
        #expect(transport.log == [
            "sets loc-en APP_IPHONE_67",
            "create set loc-en APP_IPHONE_67",
            "reserve 1.png set-new", "upload shot-1 0", "commit shot-1",
            "reserve 2.png set-new", "upload shot-2 0", "commit shot-2",
            "status shot-1", "status shot-2",
            "reorder set-new shot-1 shot-2",
        ])
        #expect(processing == 1)
        #expect(transport.uploaded("shot-1") == Self.files["/tmp/page/1.png"])
        #expect(transport.checksum("shot-2") == ScreenshotPNG.checksum(Self.files["/tmp/page/2.png"] ?? Data()))
    }

    @Test func theOldScreenshotsGoOnlyOnceTheNewOnesAreProcessed() async throws {
        let transport = FakePageScreenshotsTransport(.init(existing: ("set-ipad", ["old-1", "old-2", "old-3"]), processingChecks: 1))
        _ = try await Self.send(Self.push(display: .iPad), via: transport)
        #expect(transport.log == [
            "sets loc-en APP_IPAD_PRO_3GEN_129",
            "reserve 1.png set-ipad", "upload shot-1 0", "commit shot-1",
            "reserve 2.png set-ipad", "upload shot-2 0", "commit shot-2",
            "status shot-1", "status shot-1", "status shot-2",
            "delete old-1", "delete old-2", "delete old-3",
            "reorder set-ipad shot-1 shot-2",
        ])
    }

    @Test func whenBothWouldntFitInTenTheOldOnesGoFirst() async throws {
        let old = (1...7).map { "old-\($0)" }
        let transport = FakePageScreenshotsTransport(.init(existing: ("set-1", old)))
        _ = try await Self.send(Self.push(count: 5), via: transport)
        let log = transport.log
        #expect(Array(log.prefix(8)) == ["sets loc-en APP_IPHONE_67"] + old.map { "delete \($0)" })
        #expect(log.filter { $0.hasPrefix("delete") }.count == 7)
        #expect(log.last == "reorder set-1 shot-1 shot-2 shot-3 shot-4 shot-5")
    }

    @Test func aFailedProcessingSaysWhyAndKeepsTheOldOnes() async throws {
        let transport = FakePageScreenshotsTransport(.init(existing: ("set-1", ["old-1"]), fails: true))
        await #expect(throws: ProductPageScreenshotsPushError.refused(fileName: "1.png", details: "The image couldn’t be read.")) {
            _ = try await Self.send(Self.push(), via: transport)
        }
        #expect(!transport.log.contains { $0.hasPrefix("delete") || $0.hasPrefix("reorder") })
    }

    @Test func aMissingFileASlowUploadOrNoUploaderSaySo() async throws {
        var missing = Self.push()
        missing.content.files[1].path = "/tmp/page/gone.png"
        await #expect(throws: ProductPageScreenshotsPushError.fileMissing(fileName: "2.png")) {
            _ = try await Self.send(missing, via: FakePageScreenshotsTransport())
        }
        await #expect(throws: ProductPageScreenshotsPushError.timedOut(fileName: "1.png")) {
            _ = try await Self.send(Self.push(), via: FakePageScreenshotsTransport(.init(processingChecks: 10000)))
        }
        await #expect(throws: ProductPageScreenshotsPushError.cannotUpload) {
            _ = try await Self.push().send(into: "loc-en", via: DebugPushTransport(), readFile: { _ in Data() }, sleep: { _ in })
        }
    }

    @Test func itTravelsAsARequestAndWaitsOnlyForItsOwnPageAndLanguage() throws {
        let push = Self.push(pageID: DebugProductPagesData.PageID.privateDiary)
        let decoded = try #require(ProductPageScreenshotsPush(push.request))
        #expect(decoded == push)
        #expect(push.request.method == .post && push.request.path == "/v1/appScreenshotSets")
        #expect(push.needsPageID)
        #expect(!Self.push().needsPageID)
        #expect(push.resourceKey == "pageScreenshots:lumen:\(ProductPageBrief.key("Private diary")):en-US")
        #expect(ProductPageScreenshotsPush(PushRequest(method: .post, path: "/v1/appScreenshotSets", body: Data("{}".utf8))) == nil)

        let pages = Data("""
        {"data":[{"type":"appCustomProductPages","id":"p-1","attributes":{"name":"Prompts"}},
        {"type":"appCustomProductPages","id":"p-2","attributes":{"name":"  private DIARY "}}]}
        """.utf8)
        #expect(ProductPageScreenshotsPush.pageID(named: "Private diary", in: pages) == "p-2")
        #expect(ProductPageScreenshotsPush.pageID(named: "Mood", in: pages) == nil)
    }
}
