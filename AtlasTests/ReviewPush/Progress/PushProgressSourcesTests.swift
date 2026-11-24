//
//  PushProgressSourcesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// How the three pushes become one progress: each status as the summary
/// counts it, event art counted as an image or a video, extras by their
/// media, what the sheet shows while one runs or ended, and the viewer a
/// thumbnail opens.
@MainActor
@Suite("Push progress sources")
struct PushProgressSourcesTests {
    private let queue = ChangeQueue()

    private func makeViewModel() -> ReviewPushViewModel {
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        return ReviewPushViewModel(queue: queue, push: push, selectedAppID: "lumen", appName: { _ in "Lumen Journal" })
    }

    private static func art(_ kind: InAppEventMedia.Kind = .card, isVideo: Bool) -> InAppEventArtworkPush {
        InAppEventArtworkPush(
            localizationID: "loc-de", kind: kind, isVideo: isVideo, fileName: isVideo ? "card-de.mp4" : "card-de.png", fileSize: 1200,
            path: isVideo ? "/tmp/art/card-de.mp4" : "/tmp/art/card-de.png"
        )
    }

    private static func artChange(_ art: InAppEventArtworkPush) -> PendingChange {
        var change = PushFixtures.listing("card")
        change.section = .inAppEvents
        change.title = "Summer Sale · German"
        change.requests = [art.request]
        return change
    }

    private static func extrasRun(_ items: [ExtrasPushItem]) -> ExtrasPushRun {
        ExtrasPushRun(items: items, environment: ExtrasPushFixtures.environment(FakeAssetLibrary()))
    }

    // MARK: - States

    @Test func aConflictWasntSent() {
        #expect(PushProgressState(PushItemStatus.conflict) == .notSent)
        #expect(PushProgressState(PushItemStatus.notSent("Offline")) == .notSent)
        #expect(PushProgressState(PushItemStatus.failed("409")) == .failed("409"))
        #expect(PushProgressState(PushItemStatus.sending) == .sending)
    }

    @Test func everyScreenshotStepIsOnItsWay() {
        let steps: [ScreenshotUploadStatus] = [.keepingCopy, .reserving, .uploading(0.4), .committing]
        #expect(steps.allSatisfy { PushProgressState($0) == .sending })
        #expect(PushProgressState(ScreenshotUploadStatus.cancelled) == .notSent)
        #expect(PushProgressState(ScreenshotUploadStatus.notSent("Offline")) == .notSent)
        #expect(PushProgressState(ScreenshotUploadStatus.done) == .done)
    }

    @Test func anExtraWithAppleIsOnItsWay() {
        let steps: [ExtrasPushStatus] = [.preparing, .uploading(0.5), .processing, .placing]
        #expect(steps.allSatisfy { PushProgressState($0) == .sending })
        #expect(PushProgressState(ExtrasPushStatus.cancelled) == .notSent)
        #expect(PushProgressState(ExtrasPushStatus.done(assetID: "a", placementIDs: [])) == .done)
    }

    // MARK: - Entries

    @Test func eventArtIsAnImageOrAVideo() {
        let image = Self.art(isVideo: false)
        let item = PushItem(change: Self.artChange(image))
        let cache = PushProgressArtworkCache()
        #expect(cache.artwork(for: item) == image)
        #expect(PushProgressEntry(item: item, artwork: image).kind == .image)
        #expect(PushProgressEntry(item: item, artwork: Self.art(isVideo: true)).kind == .video)
        let text = PushItem(change: PushFixtures.listing("subtitle"))
        #expect(cache.artwork(for: text) == nil)
        let entry = PushProgressEntry(item: text, artwork: nil)
        #expect(entry.kind == .change)
        #expect(entry.id == "change.listing.de.subtitle")
        #expect(entry.title == "German · subtitle · Store Page · version 1.4")
    }

    @Test func extrasAreCountedByTheirMedia() {
        let header = PushProgressEntry(extra: ExtrasPushFixtures.header(), status: .waiting)
        #expect(header.kind == .image)
        #expect(header.id == "extra.de-header")
        #expect(PushProgressEntry(extra: ExtrasPushFixtures.preview(), status: .waiting).kind == .video)
    }

    // MARK: - Live

    @Test func theSheetShowsAnExtrasPushUntilItsDismissed() {
        let vm = makeViewModel()
        #expect(!PushProgressSummary.isShowing(vm.push))
        let run = Self.extrasRun([ExtrasPushFixtures.header(), ExtrasPushFixtures.preview()])
        vm.extras.run = run
        #expect(PushProgressSummary.isShowing(vm.push))
        let summary = PushProgressSummary(push: vm.push) { _ in nil }
        #expect(summary.entries.map(\.id) == ["extra.de-header", "extra.de-preview"])
        #expect(summary.entries.map(\.kind) == [.image, .video])
        #expect(summary.title == "0 pushed · 2 not sent", "Not started, nothing went")

        vm.extras.dismissFinished()
        #expect(vm.extras.run != nil, "A push that hasn't ended stays")
    }

    @Test func aFinishedExtrasPushIsDismissed() async {
        let vm = makeViewModel()
        let run = await ExtrasPushFixtures.push(
            [ExtrasPushFixtures.header()], environment: ExtrasPushFixtures.environment(FakeAssetLibrary())
        )
        vm.extras.run = run
        #expect(run.phase == .finished)
        let summary = PushProgressSummary(push: vm.push) { _ in nil }
        #expect(!summary.isRunning)
        #expect(summary.totalCount == 1)
        vm.extras.dismissFinished()
        #expect(vm.extras.run == nil)
        #expect(!PushProgressSummary.isShowing(vm.push))
    }

    // MARK: - Viewer

    @Test func aThumbnailOpensEveryImageAndVideoOfThePush() throws {
        let vm = makeViewModel()
        vm.extras.run = Self.extrasRun([ExtrasPushFixtures.header(), ExtrasPushFixtures.preview()])
        vm.openPushProgress(at: "extra.de-preview") { _ in nil }
        let viewer = try #require(vm.viewer)
        #expect(viewer.list.countTitle == "2 of 2")
        #expect(viewer.current.title == "German · App Preview")
        #expect(viewer.current.content == .file(ReviewViewerFile(
            url: URL(fileURLWithPath: "/tmp/extras/de-DE-preview.mov"), isVideo: true, pixelSize: PixelSize(width: 886, height: 1920),
            hasSound: true
        )))
        // An App Preview plays with its sound and controls, not muted on repeat.
        #expect(viewer.current.content.isAppPreview)
        #expect(!viewer.current.content.isMotion)
        #expect(viewer.current.content.plays)
        #expect(viewer.subtitle.hasSuffix("click the video to play or pause"), "\(viewer.subtitle)")
        #expect(!viewer.current.comparesSides)
    }

    @Test func aPushedAppPreviewKnowsItsDevice() {
        let iPad = ReviewViewerFile(url: URL(fileURLWithPath: "/tmp/p.mov"), isVideo: true, pixelSize: PixelSize(width: 1600, height: 1200), hasSound: true)
        #expect(iPad.previewFile.displayType == .iPad)
        let iPhone = ReviewViewerFile(url: URL(fileURLWithPath: "/tmp/p.mov"), isVideo: true, pixelSize: PixelSize(width: 886, height: 1920), hasSound: true)
        #expect(iPhone.previewFile.displayType == .iPhone)
        #expect(iPhone.previewFile.seconds == 0, "Its length is read from the movie")
    }

    @Test func aHeaderLoopStillPlaysMutedOnRepeat() {
        var loop = ExtrasPushFixtures.header()
        loop.kind = .motionArtwork(placementTypes: [ExtrasPushKind.productPageHeader])
        let item = ReviewPushViewModel.viewerItem(loop, status: .waiting)
        #expect(item.content.isMotion)
        #expect(!item.content.isAppPreview)
        #expect(item.subtitle.hasSuffix("plays muted on repeat"), "\(item.subtitle)")
    }

    /// Board 25: Live Now | New in the push's viewer too.
    @Test func anUploadComparesWithWhatWasLive() {
        let cell = ScreenshotCellKey(locale: "de-DE", displayType: .iPhone, slot: 0)
        let old = LiveScreenshot(id: "live-1", fileName: "old.png", checksum: "abc")
        let plan = ScreenshotPlanItem(appID: "lumen", cell: cell, slotName: "Today", content: .delete, old: old, source: .you)
        var upload = ScreenshotUploadItem(plan: plan, groupID: "g", localeName: "German")
        let item = ReviewPushViewModel.viewerItem(upload: upload)
        #expect(item.comparesSides)
        #expect(item.subtitle(.live) == "Live now on App Store Connect")
        upload.isOldDeleted = true
        #expect(ReviewPushViewModel.viewerItem(upload: upload).subtitle(.live) == "Live until this push")
        upload.plan.old = nil
        #expect(ReviewPushViewModel.viewerItem(upload: upload).subtitle(.live) == "Nothing live in this position: the push adds it")
    }

    @Test func eventArtOpensFromItsFile() {
        let art = Self.art(.details, isVideo: false)
        let item = PushItem(change: Self.artChange(art))
        let viewerItem = ReviewPushViewModel.viewerItem(art, of: item)
        #expect(viewerItem.id == "change.\(item.id)")
        #expect(viewerItem.content == .file(ReviewViewerFile(
            url: URL(fileURLWithPath: "/tmp/art/card-de.png"), isVideo: false, pixelSize: PixelSize(width: 1080, height: 1920)
        )))
        #expect(viewerItem.subtitle == "Event details · 9:16 · card-de.png · Waiting")
        #expect(!viewerItem.content.plays, "A still doesn't play")
        #expect(abs(viewerItem.content.aspect(.new) - 1920.0 / 1080.0) < 0.001)
    }

    @Test func aRowWithoutAnImageOpensNothing() {
        let vm = makeViewModel()
        vm.extras.run = Self.extrasRun([ExtrasPushFixtures.header()])
        vm.openPushProgress(at: "change.listing.de.subtitle") { _ in nil }
        #expect(vm.viewer == nil)
    }
}
