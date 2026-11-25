//
//  ProposeAssetLibraryCleanupTool.swift
//  Atlas
//

import Foundation

/// `propose_asset_library_cleanup`: suggests deleting files no page uses
/// from an app's App Asset Library. Each file is checked again; one a page
/// still shows is refused. The suggestion waits in Review & Push and in
/// the Asset Library sheet, with the files picked; deleting stays the
/// person's, after the sheet's confirmation. Nothing is deleted here, and a
/// push doesn't delete them.
struct ProposeAssetLibraryCleanupTool: MCPTool {
    /// Files one suggestion names at most.
    static let maximumFiles = 200
    var provider: MCPAssetLibrary.Provider = MCPAssetLibrary.manager(in:)
    var store = AssetLibraryCleanupStore.shared

    let definition = MCPToolDefinition(
        name: "propose_asset_library_cleanup",
        title: "Suggest an Asset Library cleanup",
        description: """
        Suggests deleting files from an app's App Asset Library that no page shows (read them with \
        get_asset_library onlyUnused: true): fileIds, and why in one sentence (e.g. “30 files from replaced \
        screenshots, 240 MB.”). Atlas checks each file again; one a page still shows is refused with the reason, \
        and the rest wait in Review & Push and in the Asset Library sheet, picked. Only the person deletes them, \
        after confirming; deleting can't be undone. A new suggestion replaces yours; withdraw: true takes it back.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "fileIds": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": .string("The files to delete, from get_asset_library (at most \(maximumFiles))."),
                ],
                "why": MCPToolDefinition.why("Why, for the person."),
                "withdraw": ["type": "boolean", "description": "true: take back your suggestion for this app; nothing else is read."],
            ]),
            required: ["appId"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = MCPAssetLibrary.target(app)
        guard context.allows(.screenshots) else { return .refused(MCPProposalKind.screenshots.refusal, target: target) }
        if try arguments.optionalBool("withdraw") == true {
            guard store.suggestion(for: app.id)?.client == context.clientName else {
                return .refused(String(localized: "No cleanup suggestion of yours waits for \(app.name).", comment: "kind:error"), target: target)
            }
            store.remove(for: app.id)
            return MCPToolOutcome(result: ["status": "withdrawn"], isError: false, logLines: [.init(target: target, outcome: .proposed)])
        }
        let ids = try Self.unique(arguments.optionalStrings("fileIds") ?? [])
        guard !ids.isEmpty else {
            throw MCPToolError.invalidArgument(name: "fileIds", expected: String(localized: "the fileIds of files no page shows, from get_asset_library"))
        }
        guard ids.count <= Self.maximumFiles else {
            return .refused(String(localized: "That’s \(ids.count) files; suggest at most \(Self.maximumFiles) at once.", comment: "kind:error"), target: target)
        }
        let why = try arguments.string("why")
        let layers = try arguments.layers()
        let manager = try MCPAssetLibrary.require(provider, in: context.workspace)
        let files = try await MCPAssetLibrary.files(of: app, manager: manager)
        let named = files.filter { ids.contains($0.id) }
        let counts = await MCPAssetLibrary.placementCounts(of: named, manager: manager)
        var refusals: [JSONValue] = []
        for id in ids where !named.contains(where: { $0.id == id }) {
            refusals.append(["fileId": .string(id), "reason": "No file has this id in the library. Read it again with get_asset_library."])
        }
        for file in named {
            switch counts[file.id] {
            case 0?: continue
            case let count?:
                refusals.append([
                    "fileId": .string(file.id),
                    "reason": .string(String(localized: "“\(file.title)” is on \(count) page placements, so Apple won’t delete it. Leave it out.", comment: "kind:error")),
                ])
            case nil:
                refusals.append(["fileId": .string(file.id), "reason": "Atlas couldn’t check whether a page shows it. Try again later."])
            }
        }
        let accepted = named.filter { counts[$0.id] == 0 }.map(\.id)
        guard !accepted.isEmpty else {
            let reason = String(localized: "None of these files can be deleted: each is on a page or wasn’t found.", comment: "kind:error")
            let result: JSONValue = ["status": "refused", "reason": .string(reason), "refused": .array(refusals)]
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reason)])
        }
        store.suggest(AssetLibraryCleanupSuggestion(appID: app.id, fileIDs: accepted, why: why, client: context.clientName, layers: layers))
        let bytes = named.filter { accepted.contains($0.id) }.compactMap(\.fileSize).reduce(0, +)
        var result: [String: JSONValue] = [
            "status": "suggested",
            "files": .int(accepted.count),
            "bytes": .int(bytes),
            "note": "It waits in Review & Push and in the Asset Library sheet; the person deletes the files after confirming.",
        ]
        if !refusals.isEmpty { result["refused"] = .array(refusals) }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    private static func unique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
