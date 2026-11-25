//
//  RetentionRemoveSubscriptionsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_retention_message`'s removeSubscriptions: a subscription comes
/// off a message only while App Store Connect doesn't show it there yet;
/// one that does is refused with how to stop it.
@MainActor
@Suite("Retention message: removing subscriptions")
struct RetentionRemoveSubscriptionsTests {
    private let changes = ChangeQueue()
    private let store = RetentionDraftStore()
    private let lumen = DebugFixtures.AppID.lumen
    private let images = FileManager.default.temporaryDirectory.appending(path: "retention-remove-\(UUID().uuidString)")

    private func message(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var all: [String: JSONValue] = ["appId": "Lumen Journal"]
        all.merge(arguments) { $1 }
        let workspace = MCPTestFixtures.workspace(changes: changes)
        let tool = ProposeRetentionMessageTool(store: store, imageDirectory: images)
        return try await tool.call(MCPToolArguments(all), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    private func reasons(_ outcome: MCPToolOutcome) -> [String] {
        outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    @Test func aSubscriptionNotYetAssignedComesOff() async throws {
        let outcome = try await message([
            "referenceName": "Come back soon", "subscriptions": ["Monthly", "Annual"], "removeSubscriptions": ["Annual"],
            "locale": "en-US", "header": "Your journal waits for you", "body": "Cancel and your entries stay.",
        ])
        #expect(outcome.result["status"] == "queued")
        let draft = try #require(store.message(appID: lumen, id: "draft-1"))
        #expect(draft.subscriptionIDs.count == 1)
    }

    @Test func removingEverySubscriptionIsRefused() async throws {
        let outcome = try await message([
            "referenceName": "Come back soon", "subscriptions": ["Annual"], "removeSubscriptions": ["Annual"],
            "locale": "en-US", "header": "Your journal waits for you", "body": "Cancel and your entries stay.",
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(!reasons(outcome).isEmpty)
    }

    @Test func aSubscriptionShowingTheLiveMessageIsRefusedWithWhatToDo() async throws {
        let outcome = try await message(["messageId": .string(RetentionSampleData.name), "removeSubscriptions": ["Monthly"]])
        #expect(outcome.result["status"] == "refused")
        #expect(reasons(outcome).contains { $0.contains("give Monthly another message") || $0.contains("another message") })
    }

    @Test func theSchemaOffersRemoveSubscriptions() {
        let properties = ProposeRetentionMessageTool().definition.inputSchema["properties"]
        #expect(properties?["removeSubscriptions"] != nil)
    }
}
#endif
