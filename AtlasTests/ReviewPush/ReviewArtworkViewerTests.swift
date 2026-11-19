//
//  ReviewArtworkViewerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Review & Push's list: a click on an event image or video opens it large,
/// with the list's other art a ← → away and text changes left out.
@MainActor
@Suite("Review & Push · event art viewer")
struct ReviewArtworkViewerTests {
    private let queue = ChangeQueue()

    private func makeViewModel() -> ReviewPushViewModel {
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        return ReviewPushViewModel(queue: queue, push: push, selectedAppID: "lumen", appName: { _ in "Lumen Journal" })
    }

    private static func art(_ id: String, kind: InAppEventMedia.Kind, isVideo: Bool, title: String) -> PendingChange {
        let push = InAppEventArtworkPush(
            localizationID: "loc-\(id)", kind: kind, isVideo: isVideo, fileName: "\(id).\(isVideo ? "mp4" : "png")", fileSize: 100,
            path: "/tmp/art/\(id).\(isVideo ? "mp4" : "png")", previewFrameTimeCode: nil
        )
        return PendingChange(
            id: "art.\(id)", appID: "lumen", section: .inAppEvents, group: "Winter", title: title, oldValue: "",
            newValue: isVideo ? "Video (0:20) · \(id).mp4" : "Image · \(id).png", requests: [push.request]
        )
    }

    @Test func aClickedVideoOpensLargeAmongTheListsArt() throws {
        let text = PendingChange(
            id: "name", appID: "lumen", section: .inAppEvents, group: "Winter", title: "German · Name", oldValue: "Winter",
            newValue: "Winterreflexion", requests: []
        )
        queue.upsert(contentsOf: [
            Self.art("de", kind: .card, isVideo: true, title: "German · Event card"),
            text,
            Self.art("fr", kind: .details, isVideo: false, title: "French · Event details"),
        ])
        let vm = makeViewModel()

        vm.openArtwork(of: "art.fr")
        let viewer = try #require(vm.viewer)
        #expect(viewer.list.items.map(\.id) == ["review.artwork.art.de", "review.artwork.art.fr"], "The text change has nothing to show")
        #expect(viewer.current.id == "review.artwork.art.fr")
        #expect(viewer.current.title == "Winter · French · Event details")
        #expect(viewer.current.subtitle.hasSuffix("Image · fr.png"), "\(viewer.current.subtitle)")
        guard case let .file(file) = viewer.current.content else {
            Issue.record("Not a file: \(viewer.current.content)")
            return
        }
        #expect(file.url.path == "/tmp/art/fr.png")
        #expect(!file.isVideo)
        #expect(file.pixelSize.height > file.pixelSize.width, "A details page is tall")

        let video = try #require(ReviewPushViewModel.artworkViewerItem(queue.changes[0]))
        guard case let .file(movie) = video.content else {
            Issue.record("Not a file")
            return
        }
        #expect(movie.isVideo)
    }

    @Test func aChangeWithoutArtOpensNothing() {
        queue.upsert(PendingChange(
            id: "name", appID: "lumen", section: .inAppEvents, group: "Winter", title: "German · Name", oldValue: "", newValue: "W", requests: []
        ))
        let vm = makeViewModel()
        vm.openArtwork(of: "name")
        #expect(vm.viewer == nil)
    }
}
