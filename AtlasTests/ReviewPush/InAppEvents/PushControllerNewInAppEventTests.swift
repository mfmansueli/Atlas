//
//  PushControllerNewInAppEventTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing a new In-App Event: the draft is created in the territories App
/// Store Connect has (read once per push), not Atlas's own table,
/// and its languages go into the event it created.
@MainActor
@Suite("PushController · new In-App Events")
struct PushControllerNewInAppEventTests {
    typealias Data = InAppEventsTestData

    private let queue = ChangeQueue()
    private let builder = InAppEventChangeBuilder(appID: Data.app.id)

    private static func transport() -> FakePushTransport {
        FakePushTransport(
            remote: [SubscriptionAvailabilityEverywhere.territoriesPath: Foundation.Data(#"{"data":[{"id":"USA"},{"id":"BRA"},{"id":"GBR"}]}"#.utf8)],
            responses: ["/v1/appEvents": Foundation.Data(#"{"data":{"type":"appEvents","id":"ev9"}}"#.utf8)]
        )
    }

    private func makeEvent(_ name: String) -> NewInAppEvent {
        var event = NewInAppEvent(now: Data.now)
        event.referenceName = name
        event.deepLink = "lumen://events/spring"
        event.texts["en-US"] = [.name: "Spring Reset", .shortDescription: "A fresh start", .longDescription: "Seven days of small habits."]
        return event
    }

    private func push(_ changes: [PendingChange], via transport: FakePushTransport) async -> PushController {
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        queue.upsert(contentsOf: changes)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    private static func territories(_ request: PushRequest) -> [String]? {
        let object = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let attributes = (object?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        return (attributes?["territorySchedules"] as? [[String: Any]])?.first?["territories"] as? [String]
    }

    @Test func aNewEventIsCreatedEverywhereAppStoreConnectSells() async throws {
        let transport = Self.transport()
        let controller = try await push([#require(builder.newEventChange(makeEvent("Spring Reset 2027")))], via: transport)

        #expect(controller.doneCount == 1)
        #expect(queue.changes.isEmpty)
        #expect(transport.sent.map(\.path) == ["/v1/appEvents", "/v1/appEventLocalizations"])
        #expect(Self.territories(transport.sent[0]) == ["USA", "BRA", "GBR"])
        let created = try #require(InAppEventWriteDocument.decode(transport.sent[1].body))
        #expect(created.data.relationships?["appEvent"]?.data.id == "ev9")
        let texts = transport.sent.map { String(bytes: $0.body ?? Foundation.Data(), encoding: .utf8) ?? "" }
        #expect(!texts.contains { $0.contains("{everyTerritory}") || $0.contains("{createdID}") })
        #expect(texts[0].contains(#""deepLink":"lumen://events/spring""#))
    }

    @Test func twoEventsReadTheTerritoriesOnce() async throws {
        let transport = Self.transport()
        _ = try await push([
            #require(builder.newEventChange(makeEvent("Spring Reset 2027"))), #require(builder.newEventChange(makeEvent("Summer Streak 2027"))),
        ], via: transport)
        #expect(transport.sent.count { $0.path == "/v1/appEvents" } == 2)
        #expect(transport.fetched.count { $0 == SubscriptionAvailabilityEverywhere.territoriesPath } == 1)
    }

    @Test func chosenTerritoriesAreSentAsTheyAre() async throws {
        var event = makeEvent("Spring Reset 2027")
        event.territories = ["USA", "BRA"]
        let transport = Self.transport()
        _ = try await push([#require(builder.newEventChange(event))], via: transport)
        #expect(Self.territories(transport.sent[0]) == ["USA", "BRA"])
        #expect(transport.fetched.isEmpty)
    }

    @Test func anEventQueuedWithTheWholeTableGetsAppStoreConnectsTerritories() async throws {
        var event = makeEvent("Spring Reset 2027")
        // As the New Event sheet queued it before the placeholder.
        event.territories = TerritoryCatalog.standard.territories.map(\.id)
        let transport = Self.transport()
        _ = try await push([#require(builder.newEventChange(event))], via: transport)
        #expect(Self.territories(transport.sent[0]) == ["USA", "BRA", "GBR"])
    }
}
