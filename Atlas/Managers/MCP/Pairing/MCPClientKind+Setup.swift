//
//  MCPClientKind+Setup.swift
//  Atlas
//

import Foundation

/// How "Set Up Your AI Assistant" presents each client: its name in the
/// list, what it can see, and what to tell the person next to the snippet.
extension MCPClientKind {
    /// "Codex CLI", "Other MCP client".
    var setupName: String {
        switch self {
        case .codex: "Codex CLI"
        case .other: String(localized: "Other MCP client")
        default: title
        }
    }

    var setupDescription: String {
        switch self {
        case .claudeCode:
            String(localized: "Reads your project’s code and git history. Best for What’s New, review notes and privacy.")
        case .claudeDesktop:
            String(localized: "Uses Atlas’s data and what you attach or paste. Sees your code only if you give access.")
        case .cursor: String(localized: "Works with the project you have open in Cursor.")
        case .codex: String(localized: "Reads the project you start it in.")
        case .other: String(localized: "Any client that can connect to a local MCP server.")
        }
    }

    /// The line above the snippet.
    var setupIntro: String {
        switch self {
        case .claudeCode: String(localized: "In Terminal, run:")
        case .claudeDesktop:
            String(localized: """
            In Claude Desktop, choose Settings → Developer → Edit Config, add this under “mcpServers” in \
            claude_desktop_config.json, then restart Claude Desktop:
            """)
        case .cursor: String(localized: "In Cursor, add this under “mcpServers” in .cursor/mcp.json, or use Settings → MCP → Add New Server:")
        case .codex: String(localized: "Add this to ~/.codex/config.toml:")
        case .other: String(localized: "Add a server to your client with this address and header:")
        }
    }

    /// The note under the snippet.
    var setupNote: String {
        switch self {
        case .claudeCode:
            String(localized: """
            Replaces Atlas’s older entry, works in every project and opens Atlas if it’s closed. Start Claude Code in each \
            app’s folder to match it to the app.
            """)
        case .claudeDesktop:
            String(localized: """
            For What’s New and privacy, use Claude Code. Claude Desktop sees code only with access.
            """)
        case .cursor: String(localized: "Open your app’s folder in Cursor.")
        case .codex: String(localized: "Start Codex in your app’s project folder.")
        case .other: String(localized: "Needs MCP tools. MCP prompts work too, if your client shows them.")
        }
    }

    /// "Copy Command", or "Copy Configuration" for a file.
    var copyTitle: String {
        self == .claudeCode ? String(localized: "Copy Command") : String(localized: "Copy Configuration")
    }
}
