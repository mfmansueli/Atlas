//
//  InAppEventArtworkPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing an event's card or details page: reserve an
/// `appEventScreenshots` or `appEventVideoClips` on the localization with
/// its asset type, upload the parts, commit, wait for Apple, then delete
/// what that asset type had.
@MainActor
@Suite("In-App Event artwork push")
struct InAppEventArtworkPushTests {
    /// 200 bytes: two parts of 100.
    private static let file = Data((0..<200).map { UInt8($0 % 251) })

    private static func push(
        kind: InAppEventMedia.Kind = .card, isVideo: Bool = false, localizationID: String = "loc-en", timeCode: String? = nil
    ) -> InAppEventArtworkPush {
        InAppEventArtworkPush(
            localizationID: localizationID, kind: kind, isVideo: isVideo, fileName: isVideo ? "loop.mov" : "card.png", fileSize: 200,
            path: "/tmp/never-read", previewFrameTimeCode: timeCode
        )
    }

    private static func send(_ push: InAppEventArtworkPush, via transport: FakeEventArtworkTransport) async throws -> String {
        try await push.send(via: transport, readFile: { _ in file }, sleep: { _ in })
    }

    private static let existing: [String: [(id: String, type: String)]] = [
        "appEventScreenshots": [("old-card", "EVENT_CARD"), ("old-details", "EVENT_DETAILS_PAGE")],
        "appEventVideoClips": [("old-clip", "EVENT_CARD")],
    ]

    @Test func anImageCardIsReservedUploadedCommittedAndReplacesTheOldOnes() async throws {
        let transport = FakeEventArtworkTransport(.init(existing: Self.existing))
        let id = try await Self.send(Self.push(), via: transport)

        #expect(id == "shot-1")
        #expect(transport.log == [
            "list appEventScreenshots loc-en", "list appEventVideoClips loc-en",
            "reserve appEventScreenshots card.png EVENT_CARD loc-en",
            "upload shot-1 0", "upload shot-1 1",
            "commit appEventScreenshots shot-1",
            "status shot-1",
            // The card's image and its video go; the details page stays.
            "delete appEventScreenshots old-card", "delete appEventVideoClips old-clip",
        ])
        #expect(transport.uploaded("shot-1") == Self.file)
        let reserve = try #require(transport.body("reserve appEventScreenshots")?["data"] as? [String: Any])
        #expect(reserve["type"] as? String == "appEventScreenshots")
        let attributes = try #require(reserve["attributes"] as? [String: Any])
        #expect(attributes["fileName"] as? String == "card.png")
        #expect(attributes["fileSize"] as? Int == 200)
        #expect(attributes["appEventAssetType"] as? String == "EVENT_CARD")
        #expect(attributes["previewFrameTimeCode"] == nil)
        let relationship = (reserve["relationships"] as? [String: Any])?["appEventLocalization"] as? [String: Any]
        #expect((relationship?["data"] as? [String: Any])?["id"] as? String == "loc-en")
        // Apple's update for event media takes `uploaded` alone, no checksum.
        let commit = transport.body("commit appEventScreenshots")?["data"] as? [String: Any]
        #expect(commit?["attributes"] as? [String: Bool] == ["uploaded": true])
    }

    @Test func aVideoDetailsPageNamesItsPosterFrameAndWaitsForProcessing() async throws {
        let transport = FakeEventArtworkTransport(.init(processingChecks: 2))
        let push = Self.push(kind: .details, isVideo: true, localizationID: "loc-de", timeCode: "00:00:01:15")
        let id = try await Self.send(push, via: transport)

        #expect(id == "clip-1")
        #expect(transport.log == [
            "list appEventScreenshots loc-de", "list appEventVideoClips loc-de",
            "reserve appEventVideoClips loop.mov EVENT_DETAILS_PAGE loc-de",
            "upload clip-1 0", "upload clip-1 1",
            "commit appEventVideoClips clip-1",
            "status clip-1", "status clip-1", "status clip-1",
        ])
        let reserve = transport.body("reserve appEventVideoClips")?["data"] as? [String: Any]
        let attributes = reserve?["attributes"] as? [String: Any]
        #expect(attributes?["appEventAssetType"] as? String == "EVENT_DETAILS_PAGE")
        #expect(attributes?["previewFrameTimeCode"] as? String == "00:00:01:15")
        let commit = (transport.body("commit appEventVideoClips")?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        #expect(commit?["uploaded"] as? Bool == true)
        #expect(commit?["previewFrameTimeCode"] as? String == "00:00:01:15")
        #expect(InAppEventArtworkRequests.statusPath(id: "clip-1", isVideo: true).hasSuffix("fields%5BappEventVideoClips%5D=videoDeliveryState"))
        #expect(InAppEventArtworkRequests.statusPath(id: "shot-1", isVideo: false).hasSuffix("fields%5BappEventScreenshots%5D=assetDeliveryState"))
    }

    @Test func whenAppleTakesOneOfATypeTheOldOneGoesFirst() async throws {
        let transport = FakeEventArtworkTransport(.init(existing: ["appEventScreenshots": [("old-card", "EVENT_CARD")]], refusesSecondOfType: true))
        _ = try await Self.send(Self.push(), via: transport)
        #expect(transport.log == [
            "list appEventScreenshots loc-en", "list appEventVideoClips loc-en",
            "reserve appEventScreenshots card.png EVENT_CARD loc-en refused",
            "delete appEventScreenshots old-card",
            "reserve appEventScreenshots card.png EVENT_CARD loc-en",
            "upload shot-1 0", "upload shot-1 1", "commit appEventScreenshots shot-1", "status shot-1",
        ])
    }

    @Test func aFailedProcessingSaysWhyAndKeepsTheOldOne() async throws {
        let transport = FakeEventArtworkTransport(.init(existing: Self.existing, fails: true))
        await #expect(throws: InAppEventArtworkPushError.refused(fileName: "card.png", details: "The image couldn’t be read.")) {
            _ = try await Self.send(Self.push(), via: transport)
        }
        #expect(!transport.log.contains { $0.hasPrefix("delete") })
    }

    @Test func aFileThatIsGoneOrAnUploadThatNeverFinishesSaysSo() async throws {
        let push = Self.push()
        await #expect(throws: InAppEventArtworkPushError.fileMissing(fileName: "card.png")) {
            _ = try await push.send(via: FakeEventArtworkTransport(), readFile: { _ in throw CocoaError(.fileNoSuchFile) }, sleep: { _ in })
        }
        let slow = FakeEventArtworkTransport(.init(processingChecks: 10000))
        await #expect(throws: InAppEventArtworkPushError.timedOut(fileName: "card.png")) {
            _ = try await Self.send(push, via: slow)
        }
        await #expect(throws: InAppEventArtworkPushError.cannotUpload) {
            _ = try await push.send(via: FakePushTransport(), readFile: { _ in Self.file }, sleep: { _ in })
        }
    }

    @Test func theQueuedRequestCarriesTheStepAndReadsBack() {
        let push = Self.push(kind: .details, isVideo: true, timeCode: "00:00:02:00")
        let request = push.request
        #expect(request.method == .post)
        #expect(request.path == "/v1/appEventVideoClips")
        #expect(InAppEventArtworkPush(request) == push)
        // A plain reservation, or any other write, isn't the step.
        let plain = InAppEventArtworkRequests.reserve(fileName: "a.png", fileSize: 1, kind: .card, isVideo: false, localizationID: "l")
        #expect(InAppEventArtworkPush(plain) == nil)
        #expect(InAppEventArtworkPush(PushRequest(method: .post, path: "/v1/appEventLocalizations", body: request.body)) == nil)
        // An image never carries a poster frame.
        #expect(Self.push(timeCode: "00:00:01:00").previewFrameTimeCode == nil)
    }

    @Test func theExistingListIsFilteredByAssetType() throws {
        let page = Data(#"""
        {"data":[{"type":"appEventScreenshots","id":"a","attributes":{"appEventAssetType":"EVENT_CARD"}},
                 {"type":"appEventScreenshots","id":"b","attributes":{"appEventAssetType":"EVENT_DETAILS_PAGE"}}]}
        """#.utf8)
        #expect(try InAppEventArtworkRequests.existingIDs(in: page, kind: .card) == ["a"])
        #expect(try InAppEventArtworkRequests.existingIDs(in: page, kind: .details) == ["b"])
        #expect(InAppEventArtworkRequests.existingPath(localizationID: "l1", isVideo: true)
            == "/v1/appEventLocalizations/l1/appEventVideoClips?fields%5BappEventVideoClips%5D=appEventAssetType&limit=50")
    }

    // MARK: - Through Review & Push

    @Test func anAcceptedChangeIsPushedAndAWaitingOneIsSkipped() async throws {
        let directory = EventArtworkTestFiles.directory()
        let fileID = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080), name: "card.png", in: directory)
        let report = try #require(await InAppEventArtworkReport.make(
            fileID: fileID, appID: InAppEventsTestData.app.id, kind: .card, language: "en-US", in: directory
        ))
        let builder = InAppEventChangeBuilder(appID: InAppEventsTestData.app.id)
        let event = InAppEventsTestData.winter
        let change = try builder.artworkChange(report, into: #require(event.localization("de-DE")), of: event, source: .assistant(client: "Claude Code"))
        #expect(change.id == "inAppEvents.\(InAppEventsTestData.app.id).winter.artwork.card.de-DE")
        #expect(change.isBlocked)
        #expect(change.blockedReason == nil)
        #expect(change.oldValue == "None")
        #expect(change.newValue == "Image · 1920 × 1080 · card.png")

        let queue = ChangeQueue()
        queue.upsert(change)
        let transport = FakeEventArtworkTransport()
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        // Waiting for the person: nothing went out.
        #expect(transport.log.isEmpty)
        #expect(queue.changes.count == 1)

        queue.accept(id: change.id)
        #expect(queue.changes.first?.isBlocked == false)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        #expect(transport.log.contains("reserve appEventScreenshots card.png EVENT_CARD loc-de"))
        #expect(transport.log.last == "status shot-1")
        #expect(queue.changes.isEmpty)
        #expect(transport.uploaded("shot-1")?.count == 200)
    }
}
