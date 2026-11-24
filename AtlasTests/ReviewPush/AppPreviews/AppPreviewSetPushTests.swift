//
//  AppPreviewSetPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing a language's App Previews changed by hand (README-Manual): the
/// version localization's set is found or made, the new videos uploaded and
/// processed first, then the live ones that go deleted, then the set put in
/// the person's order. A set takes 3, so the deletes go first only when the
/// new ones wouldn't fit.
@MainActor
@Suite("App Previews by hand push")
struct AppPreviewSetPushTests {
    private static let files: [String: Data] = [
        "/tmp/previews/a.mov": Data((0..<90).map { UInt8($0) }),
        "/tmp/previews/b.mov": Data((0..<60).map { UInt8(200 - $0) }),
    ]

    private static func file(_ name: String) -> ProductPageScreenshotsPush.File {
        ProductPageScreenshotsPush.File(path: "/tmp/previews/\(name)", fileName: name, fileSize: 1, checksum: "", mimeType: "video/quicktime")
    }

    private static func live(_ ids: [String]) -> LiveAppPreviewSet {
        LiveAppPreviewSet(
            id: "set-1", locale: "de-DE", displayType: .iPhone, previewCount: ids.count,
            previews: ids.map { LiveAppPreview(id: $0, fileName: "\($0).mov") }
        )
    }

    private static func content(live ids: [String] = []) -> AppPreviewSetPush.Content {
        .start(appID: "lumen", localizationID: "loc-de", locale: "de-DE", displayType: .iPhone, live: ids.isEmpty ? nil : live(ids))
    }

    private static func send(_ content: AppPreviewSetPush.Content, via transport: FakePageScreenshotsTransport) async throws -> String {
        try await AppPreviewSetPush(content).send(via: transport, readFile: { path in
            guard let data = files[path] else { throw CocoaError(.fileNoSuchFile) }
            return data
        }, sleep: { _ in })
    }

    @Test func aLanguageWithoutASetGetsOneAndTheVideosInOrder() async throws {
        var content = Self.content()
        content.add([Self.file("a.mov"), Self.file("b.mov")])
        let transport = FakePageScreenshotsTransport()
        let id = try await Self.send(content, via: transport)
        #expect(id == "set-new")
        #expect(transport.log == [
            "preview sets loc-de IPHONE_67",
            "create appPreviewSets loc-de IPHONE_67",
            "reserve a.mov set-new video/quicktime", "upload shot-1 0", "commit shot-1",
            "reserve b.mov set-new video/quicktime", "upload shot-2 0", "commit shot-2",
            "status shot-1", "status shot-2",
            "reorder set-new shot-1 shot-2",
        ])
        #expect(transport.uploaded("shot-1") == Self.files["/tmp/previews/a.mov"])
    }

    @Test func uploadsGoBeforeDeletesBeforeTheOrder() async throws {
        var content = Self.content(live: ["old-1", "old-2"])
        content.replace(at: 0, with: Self.file("a.mov"))
        content.move(at: 0, by: 1)
        let transport = FakePageScreenshotsTransport(.init(existing: ("set-1", ["old-1", "old-2"])))
        _ = try await Self.send(content, via: transport)
        #expect(transport.log == [
            "preview sets loc-de IPHONE_67",
            "reserve a.mov set-1 video/quicktime", "upload shot-1 0", "commit shot-1",
            "status shot-1",
            "delete old-1",
            "reorder set-1 old-2 shot-1",
        ])
    }

    @Test func whenTheNewOnesWouldntFitTheDeletesGoFirst() async throws {
        var content = Self.content(live: ["old-1", "old-2", "old-3"])
        content.replace(at: 2, with: Self.file("a.mov"))
        let transport = FakePageScreenshotsTransport(.init(existing: ("set-1", ["old-1", "old-2", "old-3"])))
        _ = try await Self.send(content, via: transport)
        #expect(Array(transport.log.prefix(2)) == ["preview sets loc-de IPHONE_67", "delete old-3"])
        #expect(transport.log.last == "reorder set-1 old-1 old-2 shot-1")
    }

    @Test func aRefusedVideoKeepsTheLiveOnes() async throws {
        var content = Self.content(live: ["old-1"])
        content.replace(at: 0, with: Self.file("a.mov"))
        let transport = FakePageScreenshotsTransport(.init(existing: ("set-1", ["old-1"]), fails: true))
        await #expect(throws: ProductPageScreenshotsPushError.refused(fileName: "a.mov", details: "The image couldn’t be read.")) {
            _ = try await Self.send(content, via: transport)
        }
        #expect(!transport.log.contains { $0.hasPrefix("delete") || $0.hasPrefix("reorder") })
    }

    @Test func aMissingVideoOrNoUploaderSaySo() async throws {
        var content = Self.content()
        content.add([Self.file("gone.mov")])
        await #expect(throws: AppPreviewSetPushError.fileMissing(fileName: "gone.mov")) {
            _ = try await Self.send(content, via: FakePageScreenshotsTransport())
        }
        await #expect(throws: ProductPageScreenshotsPushError.cannotUpload) {
            _ = try await AppPreviewSetPush(content).send(via: DebugPushTransport(), readFile: { _ in Data() }, sleep: { _ in })
        }
    }

    @Test func onlyDeletesAndANewOrderUploadNothing() async throws {
        var content = Self.content(live: ["old-1", "old-2", "old-3"])
        content.delete(at: 1)
        content.move(at: 0, by: 1)
        let transport = FakePageScreenshotsTransport(.init(existing: ("set-1", ["old-1", "old-2", "old-3"])))
        _ = try await Self.send(content, via: transport)
        #expect(transport.log == ["preview sets loc-de IPHONE_67", "delete old-2", "reorder set-1 old-3 old-1"])
    }

    @Test func itTravelsAsARequestAndWaitsForItsOwnLanguageAndDevice() {
        var content = Self.content(live: ["old-1"])
        content.add([Self.file("a.mov")])
        let push = AppPreviewSetPush(content)
        #expect(AppPreviewSetPush(push.request) == push)
        #expect(push.request.method == .post && push.request.path == "/v1/appPreviewSets")
        #expect(push.resourceKey == "appPreviews:loc-de:\(ScreenshotDisplayType.iPhone.rawValue)")
        #expect(AppPreviewSetPush(PushRequest(method: .post, path: "/v1/appPreviewSets", body: Data("{}".utf8))) == nil)
        #expect(ProductPageScreenshotsPush(push.request) == nil, "A page's own App Previews read their own body")
    }
}
