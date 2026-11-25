//
//  GetAssetLibraryTool.swift
//  Atlas
//

import Foundation

/// `get_asset_library`: the files in an app's App Asset Library (images
/// and videos Autopilot's pushes or anyone else uploaded) with how many
/// pages show each, as the Asset Library sheet lists them. Read-only.
struct GetAssetLibraryTool: MCPTool {
    static let defaultLimit = 60
    var provider: MCPAssetLibrary.Provider = MCPAssetLibrary.manager(in:)

    let definition = MCPToolDefinition(
        name: "get_asset_library",
        title: "Get the App Asset Library",
        description: """
        Lists the files in an app's App Asset Library on App Store Connect, newest first, as Atlas's Asset Library \
        sheet shows them: fileId, kind (image or video), name, Apple's state, bytes, when it was uploaded, fromAutopilot \
        and onPages (how many page placements show it; 0 means no page uses it, null that the check failed). Files a \
        later push replaced are on no page and only take room. onlyUnused: true lists only those; limit is \
        \(defaultLimit) files unless given. To suggest deleting unused ones, use propose_asset_library_cleanup. Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "onlyUnused": ["type": "boolean", "description": "true lists only files no page shows."],
                "limit": ["type": "integer", "description": .string("At most this many files (default \(defaultLimit)).")],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let manager = try MCPAssetLibrary.require(provider, in: context.workspace)
        let onlyUnused = try arguments.optionalBool("onlyUnused") ?? false
        let limit = try max(1, arguments.optionalInt("limit") ?? Self.defaultLimit)
        let files = try await MCPAssetLibrary.files(of: app, manager: manager)
        let checked = Array(files.prefix(onlyUnused ? files.count : limit))
        let counts = await MCPAssetLibrary.placementCounts(of: checked, manager: manager)
        let shown = checked.filter { !onlyUnused || counts[$0.id] == 0 }
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "count": .int(files.count),
            "unused": .int(counts.values.count { $0 == 0 }),
            "files": .array(shown.prefix(limit).map { MCPAssetLibrary.json($0, placements: counts[$0.id]) }),
        ]
        if shown.count > limit { result["more"] = .int(shown.count - limit) }
        if !onlyUnused, files.count > limit { result["more"] = .int(files.count - limit) }
        if let waiting = AssetLibraryCleanupStore.shared.suggestion(for: app.id) {
            result["cleanupSuggested"] = ["files": .int(waiting.fileIDs.count), "by": .string(waiting.client)]
        }
        return .read(.object(result), target: MCPAssetLibrary.target(app))
    }
}
