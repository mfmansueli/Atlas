//
//  AssistantConfigFileTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Atlas's entry in Claude for Mac's and Cursor's settings files: put in
/// and taken out, with the rest of the file left as it was.
@Suite("AssistantConfigFile")
struct AssistantConfigFileTests {
    private let bridge = "/Applications/Atlas.app/Contents/MacOS/atlas-mcp"

    private func object(_ data: Data?) throws -> [String: Any] {
        let data = try #require(data)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func aNewFileGetsOnlyAtlasEntry() throws {
        let data = try AssistantConfigFile.adding(AssistantConfigFile.entry(token: "al_1", bridgePath: bridge), to: nil, fileName: "mcp.json")
        let servers = try #require(object(data)["mcpServers"] as? [String: Any])
        let atlas = try #require(servers["atlas"] as? [String: Any])
        #expect(atlas["command"] as? String == bridge)
        #expect(atlas["args"] as? [String] == ["--token", "al_1"])
        #expect(AssistantConfigFile.token(in: data) == "al_1")
    }

    @Test func otherServersAndSettingsStay() throws {
        let existing = Data("""
        {"globalShortcut": "Cmd+Space", "mcpServers": {"github": {"command": "gh-mcp"}, "atlas": {"command": "old", "args": ["--token", "al_old"]}}}
        """.utf8)
        let data = try AssistantConfigFile.adding(AssistantConfigFile.entry(token: "al_new", bridgePath: bridge), to: existing, fileName: "mcp.json")
        let root = try object(data)
        #expect(root["globalShortcut"] as? String == "Cmd+Space")
        let servers = try #require(root["mcpServers"] as? [String: Any])
        #expect((servers["github"] as? [String: Any])?["command"] as? String == "gh-mcp")
        #expect(AssistantConfigFile.token(in: data) == "al_new")
    }

    @Test func anEmptyFileCountsAsNone() throws {
        let data = try AssistantConfigFile.adding(AssistantConfigFile.entry(token: "al_1", bridgePath: bridge), to: Data("  \n".utf8), fileName: "mcp.json")
        #expect(AssistantConfigFile.token(in: data) == "al_1")
    }

    @Test func aFileThatIsntJSONIsNeverOverwritten() {
        #expect(throws: AssistantConfigFile.Problem.unreadable(fileName: "mcp.json")) {
            try AssistantConfigFile.adding([:], to: Data("not json".utf8), fileName: "mcp.json")
        }
    }

    @Test func removingTakesOutOnlyAtlas() throws {
        let existing = Data(#"{"mcpServers": {"github": {"command": "gh-mcp"}, "atlas": {"command": "x"}}}"#.utf8)
        let removed = try AssistantConfigFile.removing(from: existing, fileName: "mcp.json")
        let data = try #require(removed)
        let servers = try #require(object(data)["mcpServers"] as? [String: Any])
        #expect(servers["atlas"] == nil)
        #expect(servers["github"] != nil)
    }

    @Test func removingWhatIsntThereChangesNothing() throws {
        #expect(try AssistantConfigFile.removing(from: nil, fileName: "mcp.json") == nil)
        #expect(try AssistantConfigFile.removing(from: Data(#"{"mcpServers": {}}"#.utf8), fileName: "mcp.json") == nil)
    }

    @MainActor
    @Test func thePretendFilesKeepTheEntry() throws {
        let config = InMemoryAssistantConfig()
        try config.addAtlas(to: .cursor, token: "al_c", bridgePath: bridge)
        #expect(config.token(of: .cursor) == "al_c")
        config.removeAtlas(from: .cursor)
        #expect(config.token(of: .cursor) == nil)
    }
}
