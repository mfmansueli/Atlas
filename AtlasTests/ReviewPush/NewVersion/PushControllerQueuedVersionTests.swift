//
//  PushControllerQueuedVersionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing "Create version 2.0" with the texts written for it: the version
/// is created first, then its texts go into the localizations App Store
/// Connect copied into it, and its App Review details are made when it has
/// none. When the version isn't created, its texts aren't sent and stay
/// queued.
@MainActor
@Suite("Push a new version's texts")
struct PushControllerQueuedVersionTests {
    private let queue = ChangeQueue()
    private let version = NewAppVersionChangeBuilder(appID: "app1")
        .change(for: NewAppVersion(versionString: "2.0", platform: "IOS"), showsPlatform: false)
    private static let created = ["/v1/appStoreVersions": Data(#"{"data":{"type":"appStoreVersions","id":"ver9"}}"#.utf8)]
    private static let localizations = "/v1/appStoreVersions/ver9/appStoreVersionLocalizations?fields%5BappStoreVersionLocalizations%5D=locale&limit=50"
    private static let lookup = "/v1/apps/app1/appStoreVersions?filter%5BversionString%5D=2%2E0"
        + "&filter%5Bplatform%5D=IOS&fields%5BappStoreVersions%5D=versionString,platform&limit=200"
    private static let english = Data(#"{"data":[{"id":"loc-en","attributes":{"locale":"en-US"}}]}"#.utf8)

    private var queued: QueuedAppVersion { QueuedAppVersion(change: version)! }

    private func text(_ field: String, path: String, type: String, value: String) -> PendingChange {
        let id = String(path.split(separator: "/").last ?? "")
        let body = #"{"data":{"type":"\#(type)","id":"\#(id)","attributes":{"\#(field)":"\#(value)"}}}"#
        let change = PendingChange(
            id: "text.\(field)",
            appID: "app1",
            section: .storePage,
            group: "Store Page · Version 2.0",
            title: field,
            oldValue: "",
            newValue: value,
            source: .assistant(client: "Claude Code"),
            requests: [PushRequest(method: .patch, path: path, body: Data(body.utf8))],
            conflictCheck: ConflictCheck(path: path, keyPath: ["data", "attributes", field], expected: "")
        )
        return queued.tie(change)
    }

    private var whatsNew: PendingChange {
        text("whatsNew", path: "/v1/appStoreVersionLocalizations/\(queued.localizationToken(.englishUS))",
             type: "appStoreVersionLocalizations", value: "Weekly reviews")
    }

    private func review(_ field: String, _ value: String) -> PendingChange {
        text(field, path: "/v1/appStoreReviewDetails/\(queued.reviewDetailToken)", type: "appStoreReviewDetails", value: value)
    }

    private func push(_ changes: [PendingChange], via transport: FakePushTransport) async -> PushController {
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        queue.upsert(contentsOf: changes)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    @Test func theVersionIsCreatedThenItsTextsGoIntoIt() async throws {
        let transport = FakePushTransport(remote: [Self.localizations: Self.english], responses: Self.created)
        // Queued before the version, still sent after it.
        let text = whatsNew
        let controller = await push([text, version], via: transport)
        #expect(text.dependsOn == version.id)
        #expect(text.conflictCheck == nil)
        #expect(controller.doneCount == 2)
        #expect(queue.changes.isEmpty)
        #expect(transport.sent.map(\.path) == ["/v1/appStoreVersions", "/v1/appStoreVersionLocalizations/loc-en"])
        let body = try #require(transport.sent.last?.body.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains(#""id":"loc-en""#))
        #expect(!body.contains("{queuedVersion"))
        #expect(transport.fetched == [Self.localizations])
    }

    @Test func whenTheVersionIsntCreatedItsTextsWait() async throws {
        let refusal = AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR.ATTRIBUTE.INVALID", detail: "Version is invalid.")
        let transport = FakePushTransport(
            createFailures: ["/v1/appStoreVersions": refusal],
            remote: [Self.lookup: Data(#"{"data":[]}"#.utf8)]
        )
        let controller = await push([version, whatsNew], via: transport)
        #expect(controller.doneCount == 0)
        let text = try #require(controller.items.first { $0.id == whatsNew.id })
        #expect(text.status == .notSent("Version 2.0 isn’t in App Store Connect yet. Push it first, then its texts."))
        #expect(queue.changes.map(\.id) == [version.id, whatsNew.id])
        #expect(transport.sent.map(\.path) == ["/v1/appStoreVersions"])
    }

    @Test func aVersionAnEarlierPushCreatedIsLookedUp() async {
        let found = Data(#"{"data":[{"id":"ver9","attributes":{"versionString":"2.0","platform":"IOS"}}]}"#.utf8)
        let transport = FakePushTransport(remote: [Self.lookup: found, Self.localizations: Self.english])
        let controller = await push([whatsNew], via: transport)
        #expect(controller.doneCount == 1)
        #expect(transport.fetched == [Self.lookup, Self.localizations])
        #expect(transport.sent.map(\.path) == ["/v1/appStoreVersionLocalizations/loc-en"])
    }

    @Test func notThereYetItWaitsInTheQueue() async {
        let transport = FakePushTransport(remote: [Self.lookup: Data(#"{"data":[]}"#.utf8)])
        let controller = await push([whatsNew], via: transport)
        #expect(controller.doneCount == 0)
        #expect(controller.failedCount == 0)
        #expect(queue.changes.map(\.id) == [whatsNew.id])
        #expect(transport.sent.isEmpty)
    }

    /// The subtitle goes into the app info being prepared with the new
    /// version, not the live one.
    @Test func itsSubtitleGoesIntoTheAppInfoBeingPrepared() async {
        let infos = Data(#"""
        {"data":[{"id":"info-live","attributes":{"state":"READY_FOR_DISTRIBUTION"}},
                 {"id":"info-next","attributes":{"state":"PREPARE_FOR_SUBMISSION"}}]}
        """#.utf8)
        let english = Data(#"{"data":[{"id":"ail-en","attributes":{"locale":"en-US"}}]}"#.utf8)
        let appInfos = "/v1/apps/app1/appInfos?fields%5BappInfos%5D=state&limit=50"
        let infoLocalizations = "/v1/appInfos/info-next/appInfoLocalizations?fields%5BappInfoLocalizations%5D=locale&limit=50"
        let transport = FakePushTransport(remote: [appInfos: infos, infoLocalizations: english], responses: Self.created)
        let subtitle = text("subtitle", path: "/v1/appInfoLocalizations/\(queued.appInfoLocalizationToken(.englishUS))",
                            type: "appInfoLocalizations", value: "Reflect every week")
        let category = text("primaryCategory", path: "/v1/appInfos/\(queued.appInfoToken)", type: "appInfos", value: "x")
        let controller = await push([version, subtitle, category], via: transport)
        #expect(controller.doneCount == 3)
        // The two go side by side after the version, and read its app info once.
        #expect(transport.sent.first?.path == "/v1/appStoreVersions")
        #expect(Set(transport.sent.dropFirst().map(\.path)) == ["/v1/appInfoLocalizations/ail-en", "/v1/appInfos/info-next"])
        #expect(transport.fetched.sorted() == [appInfos, infoLocalizations].sorted())
    }

    @Test func withoutOneBeingPreparedItsTheLiveOne() async {
        let infos = Data(#"{"data":[{"id":"info-live","attributes":{"state":"READY_FOR_DISTRIBUTION"}}]}"#.utf8)
        let transport = FakePushTransport(remote: ["/v1/apps/app1/appInfos?fields%5BappInfos%5D=state&limit=50": infos], responses: Self.created)
        let category = text("primaryCategory", path: "/v1/appInfos/\(queued.appInfoToken)", type: "appInfos", value: "x")
        let controller = await push([version, category], via: transport)
        #expect(controller.doneCount == 2)
        #expect(transport.sent.last?.path == "/v1/appInfos/info-live")
    }

    @Test func itsAppReviewDetailsAreMadeWithTheFirstFieldThenWrittenInto() async throws {
        var responses = Self.created
        responses["/v1/appStoreReviewDetails"] = Data(#"{"data":{"type":"appStoreReviewDetails","id":"rd1"}}"#.utf8)
        let transport = FakePushTransport(responses: responses)
        let controller = await push([version, review("notes", "Use the demo account."), review("contactEmail", "dev@example.com")], via: transport)
        #expect(controller.doneCount == 3)
        #expect(transport.sent.map(\.method) == [.post, .post, .patch])
        #expect(transport.sent.map(\.path) == ["/v1/appStoreVersions", "/v1/appStoreReviewDetails", "/v1/appStoreReviewDetails/rd1"])
        let made = try #require(transport.sent[1].body.flatMap { String(data: $0, encoding: .utf8) })
        #expect(made.contains(#""notes":"Use the demo account.""#))
        #expect(made.contains(#""appStoreVersion":{"data":{"id":"ver9","type":"appStoreVersions"}}"#))
        #expect(transport.fetched == ["/v1/appStoreVersions/ver9/appStoreReviewDetail"])
    }
}
