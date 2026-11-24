//
//  NominationsPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing a draft on this Mac with its Submit: the Create goes first and
/// the Submit names what it created; a Submit whose Create went in an
/// earlier push finds the draft by name; one with no draft isn't sent.
@MainActor
@Suite("Nominations · push")
struct NominationsPushTests {
    typealias Data = DebugNominationsData

    private static let created = Foundation.Data(#"{"data":{"type":"nominations","id":"N1"}}"#.utf8)
    private static let lookup = "/v1/nominations?filter%5Bstate%5D=DRAFT&filter%5BrelatedApps%5D=\(Data.lumen)&limit=200"

    private func push(_ changes: [PendingChange], transport: FakePushTransport) async -> PushController {
        let queue = ChangeQueue()
        queue.upsert(contentsOf: changes)
        let push = PushController(queue: queue, history: PushHistory(), transport: transport)
        push.push(queue.changes(for: Data.lumen))
        await push.waitUntilFinished()
        return push
    }

    @Test func theSubmitNamesWhatItsCreateMade() async throws {
        let builder = NominationChangeBuilder(appID: Data.lumen)
        let transport = FakePushTransport(responses: ["/v1/nominations": Self.created])
        _ = try await push([builder.create(Data.draft), builder.submit(Data.draft)], transport: transport)
        #expect(transport.sent.map(\.path) == ["/v1/nominations", "/v1/nominations/N1"])
        #expect(transport.sent.last?.bodyText == #"{"data":{"attributes":{"submitted":true},"id":"N1","type":"nominations"}}"#)
    }

    @Test func aSubmitAfterAnEarlierPushFindsTheDraftByName() async throws {
        let page = #"{"data":[{"type":"nominations","id":"N7","attributes":{"name":"Lumen 1.4: Weekly reflections"}}]}"#
        let transport = FakePushTransport(remote: [Self.lookup: Foundation.Data(page.utf8)])
        _ = try await push([NominationChangeBuilder(appID: Data.lumen).submit(Data.draft)], transport: transport)
        #expect(transport.fetched == [Self.lookup])
        #expect(transport.sent.map(\.path) == ["/v1/nominations/N7"])
    }

    @Test func aSubmitWithNoDraftIsNotSent() async throws {
        let transport = FakePushTransport(remote: [Self.lookup: Foundation.Data(#"{"data":[]}"#.utf8)])
        let push = try await push([NominationChangeBuilder(appID: Data.lumen).submit(Data.draft)], transport: transport)
        #expect(transport.sent.isEmpty)
        if case .notSent = push.items.first?.status {} else {
            Issue.record("expected notSent, got \(String(describing: push.items.first?.status))")
        }
    }
}
