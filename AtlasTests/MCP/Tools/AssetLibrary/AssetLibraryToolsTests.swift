//
//  AssetLibraryToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_asset_library` and `propose_asset_library_cleanup` on a library in
/// memory: what's on no page is listed, and only those files can be
/// suggested for deletion; the person deletes them.
@MainActor
@Suite("App Asset Library MCP tools")
struct AssetLibraryToolsTests {
    private let library = FakeAssetLibraryFiles([
        .init(id: "header-new", media: .video, name: "Header · motion · new", placements: 1),
        .init(id: "header-old", media: .video, name: "Header · motion · old", placements: 0),
        .init(id: "search-old", media: .image, name: "Search · old", placements: 0),
    ])
    private let store = AssetLibraryCleanupStore()
    private let lumen = MCPTestFixtures.apps[0]

    private var provider: MCPAssetLibrary.Provider {
        let library = library
        return { _ in library }
    }

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var all: [String: JSONValue] = ["appId": "Lumen Journal"]
        all.merge(arguments) { $1 }
        let workspace = MCPTestFixtures.workspace()
        return try await tool.call(MCPToolArguments(all), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    @Test func theLibraryIsReadWithHowManyPagesShowEachFile() async throws {
        let outcome = try await call(GetAssetLibraryTool(provider: provider), [:])
        #expect(outcome.result["count"] == .int(3))
        #expect(outcome.result["unused"] == .int(2))
        let files = try #require(outcome.result["files"]?.arrayValue)
        #expect(files.first { $0["fileId"] == "header-new" }?["onPages"] == .int(1))
        #expect(outcome.logLines.first?.outcome == .read)
    }

    @Test func onlyUnusedListsTheFilesOnNoPage() async throws {
        let outcome = try await call(GetAssetLibraryTool(provider: provider), ["onlyUnused": true])
        let ids = outcome.result["files"]?.arrayValue?.compactMap { $0["fileId"]?.stringValue }
        #expect(ids == ["header-old", "search-old"])
    }

    @Test func filesOnNoPageAreSuggestedAndAPlacedOneIsLeftOut() async throws {
        let outcome = try await call(ProposeAssetLibraryCleanupTool(provider: provider, store: store), [
            "fileIds": ["header-old", "header-new", "missing"], "why": "2 files from older pushes are on no page.",
        ])
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["files"] == .int(1))
        let refused = outcome.result["refused"]?.arrayValue?.compactMap { $0["fileId"]?.stringValue }
        #expect(refused == ["missing", "header-new"])
        #expect(store.suggestion(for: lumen.id)?.fileIDs == ["header-old"])
        // Nothing was deleted: the person does it.
        #expect(library.deleted.isEmpty)
    }

    @Test func onlyPlacedFilesAreRefused() async throws {
        let outcome = try await call(ProposeAssetLibraryCleanupTool(provider: provider, store: store), [
            "fileIds": ["header-new"], "why": "Old.",
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(store.suggestion(for: lumen.id) == nil)
    }

    @Test func noFilesThrows() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeAssetLibraryCleanupTool(provider: provider, store: store), ["fileIds": [], "why": "None."])
        }
    }

    @Test func withdrawTakesItBack() async throws {
        _ = try await call(ProposeAssetLibraryCleanupTool(provider: provider, store: store), ["fileIds": ["search-old"], "why": "Old."])
        let outcome = try await call(ProposeAssetLibraryCleanupTool(provider: provider, store: store), ["withdraw": true])
        #expect(outcome.result["status"] == "withdrawn")
        #expect(store.suggestion(for: lumen.id) == nil)
    }
}
