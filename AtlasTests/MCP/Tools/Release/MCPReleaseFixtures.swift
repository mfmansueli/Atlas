//
//  MCPReleaseFixtures.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

/// The release tools over the sample account's Lumen Journal 1.4 in one
/// phase (`DebugReleaseData`), with their own proposal store and the
/// sample's clock (Nov 16, 2026).
@MainActor
struct MCPReleaseFixtures {
    let release = FakeReleaseServices()
    let proposals = ReleaseProposalStore()
    let changes = ChangeQueue()
    var suggestions = DebugReleaseData.suggestions()
    var services: WorkspaceServices

    init(_ phase: DebugReleasePhase, encryption: EncryptionAnswer? = nil) {
        services = ReleaseDebugScenes.services(phase, encryption: encryption)
        services.inAppEvents = DebugInAppEventsServices(events: nil)
        release.status = DebugReleaseData.status(phase)
        services.release = release
        proposals.now = { DebugReleaseData.today }
    }

    private static let lumen: [String: JSONValue] = ["appId": "Lumen"]

    /// An array of strings' strings (outside `#require`, which can't take
    /// a key path).
    static func strings(_ value: JSONValue?) -> [String]? {
        value?.arrayValue?.compactMap(\.stringValue)
    }

    func context(client: String = "Claude Code") -> MCPToolContext {
        let workspace = MCPWorkspace(
            teamName: "Northpier Studio", services: services, changes: changes, pricingModes: PricingModeStore(defaults: nil),
            apps: { DebugFixtures.apps }, suggestions: suggestions
        )
        return MCPToolContext(workspace: workspace, clientName: client)
    }

    func get(_ arguments: [String: JSONValue] = [:]) async throws -> JSONValue {
        var tool = GetReleaseTool(proposals: proposals)
        tool.now = { DebugReleaseData.today }
        let outcome = try await tool.call(MCPToolArguments(Self.lumen.merging(arguments) { _, new in new }), in: context())
        return outcome.result
    }

    func propose(_ action: String, _ arguments: [String: JSONValue] = [:], client: String = "Claude Code") async throws -> JSONValue {
        var tool = ProposeReleaseActionTool(proposals: proposals)
        tool.now = { DebugReleaseData.today }
        var all: [String: JSONValue] = ["appId": "Lumen", "action": .string(action), "reason": "Approved this morning; the event starts Friday."]
        all.merge(arguments) { _, new in new }
        let outcome = try await tool.call(MCPToolArguments(all), in: context(client: client))
        return outcome.result
    }

    func withdraw(_ arguments: [String: JSONValue] = [:], client: String = "Claude Code") async throws -> JSONValue {
        let outcome = try await WithdrawReleaseActionTool(proposals: proposals).call(
            MCPToolArguments(Self.lumen.merging(arguments) { _, new in new }), in: context(client: client)
        )
        return outcome.result
    }
}
#endif
