//
//  GetAppVersionsTool.swift
//  Atlas
//

import Foundation

/// `get_app_versions`: an app's App Store versions per platform, whether a
/// new one can be created, the number Atlas would suggest, and one waiting
/// in Review & Push.
struct GetAppVersionsTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_app_versions",
        title: "Read the app's versions",
        description: """
        Returns an app's App Store versions per platform (IOS, MAC_OS, VISION_OS, TV_OS): each version's number and \
        state, the latest number, whether a new version can be created (App Store Connect has one version in \
        progress per platform: not until the current one is released), the number Atlas suggests next, and a new \
        version already waiting in Review & Push. Propose one with propose_app_version.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        ),
        proposalKind: nil
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let versions = try await MCPAppVersions.load(app, in: context)
        let result: JSONValue = [
            "app": ["appId": .string(app.id), "name": .string(app.name)],
            "platforms": .array(versions.platforms.map(versions.json(for:))),
        ]
        return .read(result, target: String(localized: "\(app.name) · Versions"))
    }
}
