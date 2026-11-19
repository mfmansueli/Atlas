//
//  PushControllerNewVersionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing "Create version 2.1": created, found by number and platform when
/// a push before created it, and failing when App Store Connect refuses a
/// number the app doesn't have.
@MainActor
@Suite("Push a new version")
struct PushControllerNewVersionTests {
    private let queue = ChangeQueue()
    private let change = NewAppVersionChangeBuilder(appID: "app1").change(for: NewAppVersion(versionString: "2.1", platform: "IOS"), showsPlatform: false)
    private static let lookup = "/v1/apps/app1/appStoreVersions?filter%5BversionString%5D=2%2E1"
        + "&filter%5Bplatform%5D=IOS&fields%5BappStoreVersions%5D=versionString,platform&limit=200"
    private static let duplicate = AppStoreConnectError.rejected(
        statusCode: 409,
        code: "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE",
        detail: "You've already used this version number."
    )

    private func push(via transport: FakePushTransport) async -> PushController {
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        queue.upsert(change)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    @Test func theRequestIsReadBack() throws {
        let request = try #require(change.requests.first)
        let create = try #require(NewAppStoreVersionCreate(request))
        #expect(create.appID == "app1")
        #expect(create.version == NewAppVersion(versionString: "2.1", platform: "IOS"))
        #expect(create.lookupPath == Self.lookup)
        #expect(NewAppStoreVersionCreate(PushRequest(method: .post, path: "/v1/subscriptions", body: change.requests.first?.body)) == nil)
    }

    @Test func aNewVersionIsCreated() async {
        let transport = FakePushTransport(responses: ["/v1/appStoreVersions": Data(#"{"data":{"type":"appStoreVersions","id":"ver9"}}"#.utf8)])
        let controller = await push(via: transport)
        #expect(controller.doneCount == 1)
        #expect(queue.changes.isEmpty)
        #expect(transport.sent.map(\.path) == ["/v1/appStoreVersions"])
        #expect(transport.fetched.isEmpty)
        #expect(controller.items.first?.createdID == "ver9")
    }

    @Test func aVersionAPushBeforeCreatedIsFound() async {
        let found = Data(#"{"data":[{"id":"ver9","attributes":{"versionString":"2.1","platform":"IOS"}}]}"#.utf8)
        let transport = FakePushTransport(createFailures: ["/v1/appStoreVersions": Self.duplicate], remote: [Self.lookup: found])
        let controller = await push(via: transport)
        #expect(controller.doneCount == 1)
        #expect(transport.fetched == [Self.lookup])
        #expect(controller.items.first?.createdID == "ver9")
    }

    @Test func aRefusedNumberTheAppDoesntHaveFails() async throws {
        let transport = FakePushTransport(createFailures: ["/v1/appStoreVersions": Self.duplicate], remote: [Self.lookup: Data(#"{"data":[]}"#.utf8)])
        let controller = await push(via: transport)
        let item = try #require(controller.items.first)
        guard case let .failed(text) = item.status else {
            Issue.record("Expected a failure, got \(item.status)")
            return
        }
        #expect(text.contains("DUPLICATE"))
        #expect(queue.change(id: change.id) != nil)
    }

    @Test func anOutageIsNotLookedUp() async {
        let transport = FakePushTransport(createFailures: ["/v1/appStoreVersions": AppStoreConnectError.server(statusCode: 500, code: nil, detail: nil)])
        _ = await push(via: transport)
        #expect(transport.fetched.isEmpty)
    }
}
