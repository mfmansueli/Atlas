//
//  AppPreviewHandTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// App Previews by hand on the Screenshots language page (README-Manual):
/// the set starts as what's live; add, replace, delete and move change the
/// places it ends with and the live ones it deletes; videos are checked
/// like App Store Connect checks them before anything is queued; each change
/// waits in Review & Push as one change per language and device, with Undo.
@MainActor
@Suite("App Previews by hand")
struct AppPreviewHandTests {
    private static let size = PixelSize(width: 886, height: 1920)

    private static func file(_ name: String) -> ProductPageScreenshotsPush.File {
        ProductPageScreenshotsPush.File(path: "/tmp/\(name)", fileName: name, fileSize: 1, checksum: "", mimeType: "video/quicktime")
    }

    private static func video(
        _ name: String = "de-1.mov", size: PixelSize? = size, seconds: Double? = 24, bytes: Int = 100
    ) -> ProductPageChosenVideo {
        ProductPageChosenVideo(fileName: name, data: Data(count: bytes), pixelSize: size, seconds: seconds)
    }

    private static func live(_ ids: [String], locale: String = "ja") -> LiveAppPreviewSet {
        LiveAppPreviewSet(
            id: "set", locale: locale, displayType: .iPhone, previewCount: ids.count,
            previews: ids.map { LiveAppPreview(id: $0, fileName: "\($0).mov") }
        )
    }

    private static func start(_ ids: [String]) -> AppPreviewSetPush.Content {
        .start(appID: "lumen", localizationID: "loc-ja", locale: "ja", displayType: .iPhone, live: live(ids))
    }

    /// Japanese with a localization and one live App Preview (the sample's).
    private func model() async -> (ScreenshotsViewModel, ChangeQueue, ProductPageFilesFolder) {
        let services = FakeScreenshotsServices(document: ScreenshotsDebugDocuments.standard, live: ScreenshotsDebugDocuments.live)
        let localizations = [StoreLocale.englishUS: "loc-en", StoreLocaleCatalog.locale(code: "ja")!: "loc-ja"]
        let context = ScreenshotsContext(primaryLocale: .englishUS, version: ScreenshotsTestFixtures.editableVersion, localizations: localizations)
        let model = ScreenshotsViewModel(app: ScreenshotsTestFixtures.app, services: services, context: context)
        await model.load()
        model.renderQueue.cancel()
        let folder = ProductPageFilesFolder(root: FileManager.default.temporaryDirectory.appending(path: "AppPreviewHandTests-\(UUID().uuidString)"))
        return (model, ChangeQueue(), folder)
    }

    // MARK: - The set

    @Test func theSetStartsAsWhatsLiveAndReplacingDeletesTheLiveOne() {
        var content = Self.start(["a", "b"])
        #expect(content.slots.map(\.liveID) == ["a", "b"])
        #expect(content.isUnchanged(from: Self.live(["a", "b"])))
        content.replace(at: 0, with: Self.file("new.mov"))
        #expect(content.slots.map(\.fileName) == ["new.mov", "b.mov"])
        #expect(content.slots[0].replacesID == "a")
        #expect(content.deletedIDs == ["a"])
        // Replacing the file again still replaces the live one, once.
        content.replace(at: 0, with: Self.file("newer.mov"))
        #expect(content.deletedIDs == ["a"])
        #expect(content.slots[0].replacesID == "a")
        #expect(!content.isUnchanged(from: Self.live(["a", "b"])))
    }

    @Test func aSetTakesThreeAndMovesSwapNeighbors() {
        var content = Self.start(["a"])
        let added = content.add([Self.file("1.mov"), Self.file("2.mov"), Self.file("3.mov")])
        #expect(added == 2)
        #expect(!content.hasRoom)
        let moved = content.move(at: 0, by: 1)
        #expect(moved)
        #expect(content.slots.map(\.fileName) == ["1.mov", "a.mov", "2.mov"])
        let movedPastTheEnd = content.move(at: 2, by: 1)
        #expect(!movedPastTheEnd, "Nothing after the last one")
        let deleted = content.delete(at: 1)
        #expect(deleted)
        #expect(content.deletedIDs == ["a"])
        #expect(content.slots.count == 2)
    }

    @Test func movingBackIsUnchanged() {
        var content = Self.start(["a", "b"])
        content.move(at: 0, by: 1)
        #expect(!content.isUnchanged(from: Self.live(["a", "b"])))
        content.move(at: 1, by: -1)
        #expect(content.isUnchanged(from: Self.live(["a", "b"])))
    }

    @Test func theChangeSaysWhatThePushDoes() {
        var content = Self.start(["a", "b"])
        content.replace(at: 0, with: Self.file("new.mov"))
        content.delete(at: 1)
        content.add([Self.file("extra.mov")])
        let change = AppPreviewHandChange.change(content, localeName: "Japanese", liveCount: 2)
        #expect(change.id == "screenshots.appPreviews.lumen.ja.\(ScreenshotDisplayType.iPhone.rawValue)")
        #expect(change.section == .screenshots)
        #expect(change.title == "Japanese · App Previews")
        #expect(change.group == "App Previews · iPhone 6.9″")
        #expect(change.oldValue == "2 App Previews")
        #expect(change.newValue == "2 App Previews · 2 new · 1 deleted")
        #expect(AppPreviewHandChange.content(of: change) == content)
        #expect(AppPreviewHandChange.isChange(change))
    }

    // MARK: - Checking before queueing

    @Test func everyProblemIsSaidAtOnceWithItsFix() {
        let problems = ProductPageVideoCheck.problems(
            [
                Self.video("wrong.mov", size: PixelSize(width: 1080, height: 1920), seconds: 9),
                Self.video("clip.avi"),
                Self.video("big.mp4", bytes: 0),
            ],
            displayType: .iPhone, kept: 0
        )
        #expect(problems == [
            "“clip.avi” isn’t a MOV, MP4 or M4V video Atlas can read.",
            "“wrong.mov” is 1080 × 1920. iPhone 6.9″ takes 886 × 1920, upright or turned.",
            "“wrong.mov” is 9 seconds long. An App Preview is 15 to 30 seconds.",
        ])
        #expect(ProductPageVideoCheck.problems([Self.video("turned.m4v", size: Self.size.rotated)], displayType: .iPhone, kept: 0).isEmpty)
    }

    @Test func aFullSetTakesNoMore() {
        let problems = ProductPageVideoCheck.problems([Self.video(), Self.video("de-2.mov")], displayType: .iPhone, kept: 2)
        #expect(problems == ["The set has 2 and you chose 2. A set takes up to 3."])
    }

    // MARK: - On the language page

    @Test func addingQueuesOneChangeWithUndo() async throws {
        let (model, queue, folder) = await model()
        let before = try #require(model.appPreviewSet(locale: "ja", displayType: .iPhone, queue: queue))
        #expect(before.slots.map(\.liveID) == ["preview|ja|0"])
        model.addChosenAppPreviews([Self.video("ja-2.mov")], locale: "ja", displayType: .iPhone, queue: queue, folder: folder)
        let change = try #require(AppPreviewHandChange.queued(in: queue, appID: model.app.id, locale: "ja", displayType: .iPhone))
        let content = try #require(AppPreviewHandChange.content(of: change))
        #expect(content.slots.map(\.fileName) == ["Lumen-ja.mov", "ja-2.mov"])
        #expect(content.localizationID == "loc-ja")
        #expect(content.slots[1].file?.mimeType == "video/quicktime")
        #expect(FileManager.default.fileExists(atPath: content.slots[1].file?.path ?? ""))
        #expect(model.captionToast?.text == "Added 1 App Preview to Japanese. In Review & Push.")
        #expect(model.captionToast?.canUndo == true)

        await model.captionUndo?()
        #expect(AppPreviewHandChange.queued(in: queue, appID: model.app.id, locale: "ja", displayType: .iPhone) == nil)
        try? FileManager.default.removeItem(at: folder.root)
    }

    @Test func aRefusedVideoQueuesNothingAndSaysWhy() async {
        let (model, queue, folder) = await model()
        model.addChosenAppPreviews([Self.video(seconds: 40)], locale: "ja", displayType: .iPhone, queue: queue, folder: folder)
        #expect(model.appPreviewProblems == ["“de-1.mov” is 40 seconds long. An App Preview is 15 to 30 seconds."])
        #expect(queue.changes.isEmpty)
    }

    @Test func replacingDeletingAndMovingBackLeaveNothingToPush() async throws {
        let (model, queue, folder) = await model()
        model.addChosenAppPreviews([Self.video("ja-new.mov")], replacing: 0, locale: "ja", displayType: .iPhone, queue: queue, folder: folder)
        var content = try #require(model.appPreviewSet(locale: "ja", displayType: .iPhone, queue: queue))
        #expect(content.slots.map(\.fileName) == ["ja-new.mov"])
        #expect(content.deletedIDs == ["preview|ja|0"])
        #expect(model.captionToast?.text == "Replaced App Preview 1 in Japanese. In Review & Push.")

        model.deleteAppPreview(at: 0, locale: "ja", displayType: .iPhone, queue: queue)
        content = try #require(model.appPreviewSet(locale: "ja", displayType: .iPhone, queue: queue))
        #expect(content.slots.isEmpty)
        #expect(content.deletedIDs == ["preview|ja|0"])
        #expect(model.captionToast?.text == "App Preview 1 will be deleted in Japanese when you push.")
        try? FileManager.default.removeItem(at: folder.root)
    }

    @Test func aLanguageWithoutALocalizationHasNoSet() async {
        let (model, queue, _) = await model()
        #expect(model.appPreviewSet(locale: "de-DE", displayType: .iPhone, queue: queue) == nil)
        #expect(model.takesAppPreviews(.iPad))
        #expect(!model.takesAppPreviews(.watch))
    }

    @Test func theDebugSceneQueuesAChangedSet() throws {
        let content = try #require(AppPreviewHandChange.content(of: AppPreviewHandDebugScenes.changed))
        #expect(content.slots.count == 3)
        #expect(content.slots.last?.proposedBy == "Claude Code")
        #expect(AppPreviewHandDebugScenes.ids == ["ap-hand", "ap-hand-changed", "ap-hand-problem"])
    }
}
#endif
