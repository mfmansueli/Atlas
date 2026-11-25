//
//  ClaudeCodeAgentPermissionsTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Runs that write several languages start one native-speaker agent per
/// language, so they may use Claude Code's Agent tool; the others may not.
@Suite("Claude Code permissions: agents")
struct ClaudeCodeAgentPermissionsTests {
    private let port: UInt16 = 47321

    @Test func readingRunsAndTheChatMayStartAgents() {
        for permissions in [ClaudeCodePermissions.readProject, .chat] {
            #expect(permissions.tools.contains("Agent"), "\(permissions)")
            #expect(permissions.allowRules(port: port).contains("Agent"), "\(permissions)")
            #expect(permissions.systemPrompt.contains("one agent per language"))
        }
        for purpose: ClaudeCodeRunPurpose in [.translation, .captions, .suggestEverything, .ask(area: "Store Page")] {
            #expect(purpose.permissions.tools.contains("Agent"), "\(purpose.title)")
        }
    }

    @Test func otherRunsDont() {
        for permissions in ClaudeCodePermissions.allCases where ![.readProject, .chat].contains(permissions) {
            #expect(!permissions.tools.contains("Agent"), "\(permissions)")
            #expect(!permissions.allowRules(port: port).contains("Agent"), "\(permissions)")
            #expect(!permissions.systemPrompt.contains("Agent tool"), "\(permissions)")
        }
    }
}
