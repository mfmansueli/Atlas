//
//  MCPClientKindTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("MCPClientKind")
struct MCPClientKindTests {
    private let token = "al_pair_C7Q2m9xV4k"
    private let url = "http://127.0.0.1:47321/mcp"
    private let bridge = "/Applications/Atlas.app/Contents/MacOS/atlas-mcp"

    private func snippet(_ kind: MCPClientKind) -> String {
        kind.setupSnippet(token: token, url: url, bridgePath: bridge)
    }

    /// One registration for every project, replacing the older one whose
    /// token Atlas would refuse.
    @Test func claudeCodeGetsOneCommandForEveryProject() {
        let expected = #"claude mcp remove atlas --scope user >/dev/null 2>&1; "#
            + #"claude mcp add --scope user --transport http atlas http://127.0.0.1:47321/mcp --header "Authorization: Bearer al_pair_C7Q2m9xV4k""#
        #expect(snippet(.claudeCode) == expected)
    }

    @Test func clientsThatLaunchServersUseTheBridge() {
        for kind in [MCPClientKind.claudeDesktop, .codex] {
            #expect(kind.usesBridge)
            #expect(snippet(kind).contains(bridge))
            #expect(snippet(kind).contains(#""--token", "al_pair_C7Q2m9xV4k""#))
            #expect(!snippet(kind).contains(url))
        }
        #expect(snippet(.codex).hasPrefix("[mcp_servers.atlas]"))
        #expect(snippet(.claudeDesktop).hasPrefix(#""atlas": {"#))
    }

    @Test func httpClientsGetTheURLAndHeader() {
        for kind in [MCPClientKind.claudeCode, .cursor, .other] {
            #expect(!kind.usesBridge)
            #expect(snippet(kind).contains(url))
            #expect(snippet(kind).contains("Bearer al_pair_C7Q2m9xV4k"))
        }
    }

    @Test func connectingClientsAreRecognizedByName() {
        #expect(MCPClientKind.matching(clientName: "claude-code") == .claudeCode)
        #expect(MCPClientKind.matching(clientName: "claude-code-motivator") == .claudeCode)
        #expect(MCPClientKind.matching(clientName: "claude-codex") == nil)
        #expect(MCPClientKind.matching(clientName: "claude-ai") == .claudeDesktop)
        #expect(MCPClientKind.matching(clientName: "Cursor-vscode") == .cursor)
        #expect(MCPClientKind.matching(clientName: "codex-mcp-client") == .codex)
        #expect(MCPClientKind.matching(clientName: "zed") == nil)
    }

    @Test func otherIsTitledByWhatItIs() {
        #expect(MCPClientKind.other.pickerTitle == "Other")
        #expect(MCPClientKind.other.title == "MCP client")
        #expect(MCPClientKind.cursor.pickerTitle == "Cursor")
    }
}
