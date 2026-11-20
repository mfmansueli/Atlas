//
//  GetInAppEventsPartsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_in_app_events`' `eventId` and `include`: one event, or the parts
/// asked for. Without `include`, every part but the two heaviest,
/// mediaDetails and design, and the result says how to ask for them.
@MainActor
@Suite("get_in_app_events · eventId and include")
struct GetInAppEventsPartsTests {
    typealias Data = InAppEventsTestData

    private func read(_ arguments: [String: JSONValue]) async throws -> JSONValue {
        var workspace = MCPTestFixtures.workspace()
        workspace.services.inAppEvents = FakeInAppEventsServices(Data.events)
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code")
        var all: [String: JSONValue] = ["appId": "Lumen Journal"]
        all.merge(arguments) { $1 }
        let tool = GetInAppEventsTool(store: InAppEventsStore(), directory: EventArtworkTestFiles.directory(), now: { Data.now })
        return try await tool.call(MCPToolArguments(all), in: context).result
    }

    private static func keys(_ value: JSONValue?) -> Set<String> {
        Set(value?.objectValue?.keys.map(\.self) ?? [])
    }

    private static let base: Set<String> = ["id", "referenceName", "state", "editable", "deepLink", "showsFrom"]

    @Test func byDefaultTheHeaviestPartsAreLeftOutAndSaidHow() async throws {
        let result = try await read([:])
        #expect(result["design"] == nil)
        let winter = try #require(result["events"]?.arrayValue?.first { $0["id"] == "winter" })
        #expect(winter["mediaDetails"] == nil)
        #expect(winter["texts"] != nil)
        #expect(winter["media"] != nil)
        #expect(winter["missingForReview"] != nil)
        #expect(result["textRules"] != nil)
        #expect(result["artworkUpload"] != nil)
        #expect(result["leftOut"]?.arrayValue == ["mediaDetails", "design"])
        let note = try #require(result["leftOutNote"]?.stringValue)
        #expect(note.contains("include"))
        #expect(note.contains("[\"mediaDetails\"]"))
        #expect(note.contains("eventId"))
    }

    @Test func allIncludesEveryPart() async throws {
        let result = try await read(["include": ["all"]])
        #expect(result["design"] != nil)
        #expect(result["events"]?.arrayValue?.first?["mediaDetails"] != nil)
        #expect(result["leftOut"] == nil)
        #expect(result["leftOutNote"] == nil)
    }

    @Test func onlyThePartsAskedForCome() async throws {
        let result = try await read(["include": ["texts"]])
        let winter = try #require(result["events"]?.arrayValue?.first)
        #expect(Self.base.isSubset(of: Self.keys(winter)))
        #expect(winter["texts"] != nil)
        #expect(winter["media"] == nil)
        #expect(winter["missingForReview"] == nil)
        #expect(winter["deepLinkCheck"] == nil)
        #expect(result["textRules"] != nil)
        #expect(result["artworkUpload"] == nil)
        #expect(result["queued"] == nil)
        #expect(result["pushInProgress"] == nil)
        #expect(Set(result["leftOut"]?.arrayValue?.compactMap(\.stringValue) ?? []) == [
            "media", "mediaDetails", "review", "deepLinkCheck", "design", "push", "queued",
        ])
    }

    @Test func oneEventById() async throws {
        let result = try await read(["eventId": "update", "include": ["media"]])
        let events = try #require(result["events"]?.arrayValue)
        #expect(events.map { $0["id"] } == ["update"])
        #expect(events[0]["media"] != nil)
    }

    @Test func anUnknownEventOrPartIsAnError() async throws {
        await #expect(throws: MCPToolError.self) { _ = try await read(["eventId": "spring"]) }
        await #expect(throws: MCPToolError.self) { _ = try await read(["include": ["artwork"]]) }
    }

    @Test func partsReadByName() throws {
        #expect(try GetInAppEventsPart.parts(nil) == GetInAppEventsPart.standard)
        #expect(try GetInAppEventsPart.parts(["ALL"]) == Set(GetInAppEventsPart.allCases))
        #expect(try GetInAppEventsPart.parts(["mediadetails", "Design"]) == [.mediaDetails, .design])
        #expect(!GetInAppEventsPart.standard.contains(.mediaDetails))
        #expect(!GetInAppEventsPart.standard.contains(.design))
        // Every key a part adds belongs to it alone.
        let keys = GetInAppEventsPart.allCases.flatMap { Array($0.eventKeys) + Array($0.resultKeys) }
        #expect(Set(keys).count == keys.count)
    }

    @Test func theToolAndTheServerSayHow() {
        let definition = GetInAppEventsTool().definition
        #expect(definition.description.contains("`leftOut`"))
        #expect(definition.inputSchema["properties"]?["eventId"] != nil)
        #expect(definition.inputSchema["properties"]?["include"]?["items"]?["enum"]?.arrayValue?.contains("mediaDetails") == true)
        #expect(MCPEndpoint.instructions.contains("get_in_app_events takes eventId"))
        #expect(MCPEndpoint.instructions.contains("fields: [\"whatsNew\"]"))
    }
}
