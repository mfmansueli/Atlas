//
//  MCPEndpointVoiceTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The server instructions tell the assistant how to write for a card,
/// right after their second sentence (mcp-copy-changes §2).
@Suite("MCP instructions · voice")
struct MCPEndpointVoiceTests {
    @Test func theVoiceParagraphFollowsTheSecondSentence() {
        let instructions = MCPEndpoint.instructions
        let second = "Read with the list_ and get_ tools. "
        #expect(instructions.contains(second + MCPEndpoint.voice + " Change things with the propose_ tools"))
        #expect(instructions.hasPrefix("Atlas manages the App Store Connect data"))
    }

    @Test func theVoiceNamesTheLimits() {
        #expect(MCPEndpoint.voice.contains("at most 8 words"))
        #expect(MCPEndpoint.voice.contains("at most \(AssistantTextLimits.why) characters"))
        #expect(MCPEndpoint.voice.contains("Everything else goes in details."))
    }
}
