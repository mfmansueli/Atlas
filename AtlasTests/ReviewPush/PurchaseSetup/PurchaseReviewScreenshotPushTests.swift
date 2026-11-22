//
//  PurchaseReviewScreenshotPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A product's App Review screenshot upload: reserve, upload the parts,
/// commit with the MD5 and wait for Apple; the old one deleted first, and
/// the same file already there left alone.
@MainActor
@Suite("PurchaseReviewScreenshotPush")
struct PurchaseReviewScreenshotPushTests {
    private static let bytes = Data((0..<1000).map { UInt8($0 % 251) })
    private static let checksum = ScreenshotPNG.checksum(bytes)

    private static func step(_ owner: PurchaseReviewScreenshotOwner = .subscription, ownerID: String = "sub1") -> PurchaseReviewScreenshotPush {
        PurchaseReviewScreenshotPush(owner: owner, ownerID: ownerID, fileName: "paywall.png", fileSize: 1000, path: "/tmp/paywall.png", checksum: checksum)
    }

    private func send(_ step: PurchaseReviewScreenshotPush, via transport: FakeReviewScreenshotTransport) async throws -> String {
        try await step.send(via: transport, readFile: { _ in Self.bytes }, sleep: { _ in })
    }

    @Test func theRequestIsTheReservationWithTheFileBeside() throws {
        let request = Self.step().request
        #expect(request.method == .post)
        #expect(request.path == "/v1/subscriptionAppStoreReviewScreenshots")
        let body = try #require(PushPagedRead.body(of: request))
        let data = try #require(body["data"] as? [String: Any])
        #expect(data["type"] as? String == "subscriptionAppStoreReviewScreenshots")
        #expect((data["attributes"] as? [String: Any])?["fileName"] as? String == "paywall.png")
        #expect((data["attributes"] as? [String: Any])?["fileSize"] as? Int == 1000)
        #expect(PushPagedRead.relationshipID("subscription", of: data) == "sub1")
        #expect((body["atlas"] as? [String: Any])?["file"] as? String == "/tmp/paywall.png")
        #expect(PurchaseReviewScreenshotPush(request) == Self.step())
        // What Apple gets has no Atlas key.
        #expect(PushPagedRead.body(of: Self.step().reservation)?["atlas"] == nil)
    }

    @Test func anInAppPurchasesScreenshotBelongsToItsV2Resource() throws {
        let step = Self.step(.inAppPurchase, ownerID: "iap9")
        let data = try #require(PushPagedRead.body(of: step.request)?["data"] as? [String: Any])
        #expect(step.request.path == "/v1/inAppPurchaseAppStoreReviewScreenshots")
        #expect(PushPagedRead.relationshipID("inAppPurchaseV2", of: data) == "iap9")
        #expect(PurchaseReviewScreenshotOwner.inAppPurchase.currentPath(ownerID: "iap9").hasPrefix("/v2/inAppPurchases/iap9/appStoreReviewScreenshot?"))
        #expect(PurchaseReviewScreenshotPush(step.request)?.owner == .inAppPurchase)
    }

    @Test func aProductWithoutOneGetsItReservedUploadedAndCommitted() async throws {
        let transport = FakeReviewScreenshotTransport()
        let id = try await send(Self.step(), via: transport)

        #expect(id == "rs1")
        #expect(transport.log == [
            "current sub1", "reserve paywall.png 1000 sub1", "upload rs1 0", "upload rs1 1", "commit rs1 \(Self.checksum) true",
            "status rs1", "status rs1",
        ])
        #expect(transport.uploaded == Self.bytes)
    }

    @Test func anotherScreenshotIsDeletedFirst() async throws {
        let transport = FakeReviewScreenshotTransport(.init(current: ("old1", "other", "COMPLETE"), processingChecks: 0))
        _ = try await send(Self.step(), via: transport)
        #expect(Array(transport.log.prefix(3)) == ["current sub1", "delete old1", "reserve paywall.png 1000 sub1"])
    }

    @Test func theSameFileAlreadyThereIsLeftAlone() async throws {
        let transport = FakeReviewScreenshotTransport(.init(current: ("same1", Self.checksum, "COMPLETE")))
        let id = try await send(Self.step(), via: transport)
        #expect(id == "same1")
        #expect(transport.log == ["current sub1"])
    }

    @Test func theSameFileStillUploadingIsReplaced() async throws {
        let transport = FakeReviewScreenshotTransport(.init(current: ("half1", Self.checksum, "AWAITING_UPLOAD"), processingChecks: 0))
        _ = try await send(Self.step(), via: transport)
        #expect(transport.log.contains("delete half1"))
    }

    @Test func applesRefusalSaysWhy() async {
        let transport = FakeReviewScreenshotTransport(.init(fails: true))
        await #expect(throws: PurchaseReviewScreenshotPushError.refused(fileName: "paywall.png", details: "The image couldn't be read.")) {
            _ = try await send(Self.step(), via: transport)
        }
    }

    @Test func aMissingFileStopsBeforeAnythingIsSent() async {
        let transport = FakeReviewScreenshotTransport()
        await #expect(throws: PurchaseReviewScreenshotPushError.fileMissing(fileName: "paywall.png")) {
            _ = try await Self.step().send(via: transport, readFile: { _ in throw CocoaError(.fileNoSuchFile) }, sleep: { _ in })
        }
        #expect(transport.log.isEmpty)
    }

    @Test func aTransportThatCantUploadIsRefused() async {
        await #expect(throws: PurchaseReviewScreenshotPushError.cannotUpload) {
            _ = try await Self.step().send(via: FakePushTransport(), readFile: { _ in Self.bytes }, sleep: { _ in })
        }
    }

    @Test func theStateReadsAppleAssetDelivery() {
        #expect(PurchaseReviewScreenshotState(resource: nil) == .missing)
        let done: [String: Any] = ["attributes": ["fileName": "a.png", "sourceFileChecksum": "x", "assetDeliveryState": ["state": "COMPLETE"]]]
        #expect(PurchaseReviewScreenshotState(resource: done).isUploaded)
        #expect(PurchaseReviewScreenshotState(resource: done).fileName == "a.png")
        let failed: [String: Any] = ["attributes": ["fileName": "a.png", "assetDeliveryState": ["state": "FAILED"]]]
        #expect(!PurchaseReviewScreenshotState(resource: failed).isUploaded)
        #expect(PurchaseReviewScreenshotState.missing.code == "MISSING")
    }
}
