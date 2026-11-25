//
//  MCPAssetLibrary.swift
//  Atlas
//

import Foundation

/// An app's App Asset Library as the asset library tools read it: the
/// files and how many placements show each, through Review & Push's
/// services (the same the Asset Library sheet uses). Reading never writes.
@MainActor
enum MCPAssetLibrary {
    /// Where the tools reach the library; tests swap it.
    typealias Provider = @MainActor (MCPWorkspace) -> (any AssetLibraryManaging)?

    /// How many placements are checked at once, as the sheet does.
    static let checkWidth = AssetLibraryModel.checkWidth

    static func manager(in workspace: MCPWorkspace) -> (any AssetLibraryManaging)? {
        MCPPageTests.provider(in: workspace)?.assetLibraryFiles
    }

    static func require(_ provider: Provider, in workspace: MCPWorkspace) throws -> any AssetLibraryManaging {
        guard let manager = provider(workspace) else {
            throw MCPToolError.unavailable(String(localized: "Atlas can’t reach the App Asset Library with this account’s connection.", comment: "kind:error"))
        }
        return manager
    }

    static func files(of app: StoreApp, manager: any AssetLibraryManaging) async throws -> [AssetLibraryFile] {
        do {
            return try await manager.assetLibraryFiles(appID: app.id)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s App Asset Library: \(error.localizedDescription)", comment: "kind:error"))
        }
    }

    /// How many placements show each file; a file whose check failed is
    /// left out.
    static func placementCounts(of files: [AssetLibraryFile], manager: any AssetLibraryManaging) async -> [AssetLibraryFile.ID: Int] {
        var counts: [AssetLibraryFile.ID: Int] = [:]
        await withTaskGroup(of: (AssetLibraryFile.ID, Int?).self) { group in
            var next = 0
            while next < min(checkWidth, files.count) {
                let file = files[next]
                group.addTask { await (file.id, try? manager.assetLibraryPlacementCount(file.asset)) }
                next += 1
            }
            while let (id, count) = await group.next() {
                if let count { counts[id] = count }
                if next < files.count {
                    let file = files[next]
                    group.addTask { await (file.id, try? manager.assetLibraryPlacementCount(file.asset)) }
                    next += 1
                }
            }
        }
        return counts
    }

    static func json(_ file: AssetLibraryFile, placements: Int?) -> JSONValue {
        var object: [String: JSONValue] = [
            "fileId": .string(file.id),
            "kind": .string(file.media.rawValue),
            "name": .string(file.title),
            "state": .string(file.stateTitle),
            "onPages": placements.map(JSONValue.int) ?? .null,
            "fromAutopilot": .bool(file.isFromAutopilot),
        ]
        if let size = file.fileSize { object["bytes"] = .int(size) }
        if let date = file.createdDate { object["uploaded"] = .string(date.formatted(.iso8601)) }
        if let pixels = file.pixelSize { object["pixels"] = .string("\(pixels.width)×\(pixels.height)") }
        return .object(object)
    }

    static func target(_ app: StoreApp) -> String {
        String(localized: "\(app.name) · App Asset Library", comment: "kind:other")
    }
}
