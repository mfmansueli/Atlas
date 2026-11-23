//
//  ConnectableAssistant.swift
//  Atlas
//

import Foundation

/// The assistants Settings → AI Assistants connects with one click (board
/// 48, November 22): each one's name, tile, how Atlas finds it on this Mac
/// and where it keeps its MCP servers.
///
/// - Claude Code keeps them in `~/.claude.json`, which only `claude mcp
///   add` should write: Atlas runs that through its helper, outside the
///   sandbox (`ClaudeCodeLauncher+Connect`).
/// - Claude for Mac keeps them in `~/Library/Application Support/Claude/
///   claude_desktop_config.json`, Cursor in `~/.cursor/mcp.json`. The
///   sandbox lets Atlas write there only after the person chooses that
///   folder once (`AssistantConfigAccess`).
enum ConnectableAssistant: String, CaseIterable, Identifiable, Codable, Sendable {
    case claudeCode
    case claudeForMac
    case cursor

    var id: Self { self }

    var title: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .claudeForMac: "Claude for Mac"
        case .cursor: "Cursor"
        }
    }

    /// "Get Claude…": the product's own short name.
    var productName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .claudeForMac: "Claude"
        case .cursor: "Cursor"
        }
    }

    /// The letters on its tile.
    var monogram: String {
        switch self {
        case .claudeCode, .claudeForMac: "C"
        case .cursor: "Cu"
        }
    }

    /// The tile's color, as the design draws it.
    var tileHex: UInt32 {
        switch self {
        case .claudeCode: 0xD97757
        case .claudeForMac: 0xB5563C
        case .cursor: 0x3A3A3C
        }
    }

    /// The pairing it connects as, so Activity, the toolbar and the source
    /// tags read as before.
    var clientKind: MCPClientKind {
        switch self {
        case .claudeCode: .claudeCode
        case .claudeForMac: .claudeDesktop
        case .cursor: .cursor
        }
    }

    init?(clientKind: MCPClientKind) {
        guard let assistant = Self.allCases.first(where: { $0.clientKind == clientKind }) else { return nil }
        self = assistant
    }

    /// The Mac app's bundle identifier; Claude Code is a command.
    var bundleIdentifier: String? {
        switch self {
        case .claudeCode: nil
        case .claudeForMac: "com.anthropic.claudefordesktop"
        case .cursor: "com.todesktop.230313mzl4w4u92"
        }
    }

    /// Where to get it.
    var downloadURL: URL {
        switch self {
        case .claudeCode: URL(string: "https://claude.com/product/claude-code")!
        case .claudeForMac: URL(string: "https://claude.ai/download")!
        case .cursor: URL(string: "https://cursor.com/download")!
        }
    }

    /// Whether it reads the project folder. Claude for Mac has no access
    /// to this Mac's files of its own, so it isn't asked for one.
    var readsProject: Bool {
        self != .claudeForMac
    }

    /// Whether Atlas can send it a prompt and read the answer: only Claude
    /// Code, which Atlas starts itself. The others' hello says what Atlas
    /// saw of them instead.
    var answersAtlas: Bool {
        self == .claudeCode
    }

    /// The folder holding its MCP settings, under the person's home; nil
    /// for Claude Code, which its own command writes.
    var configFolder: String? {
        switch self {
        case .claudeCode: nil
        case .claudeForMac: "Library/Application Support/Claude"
        case .cursor: ".cursor"
        }
    }

    var configFileName: String? {
        switch self {
        case .claudeCode: nil
        case .claudeForMac: "claude_desktop_config.json"
        case .cursor: "mcp.json"
        }
    }

    /// What the person is told about the folder it reads.
    var folderAccessText: String {
        switch self {
        case .claudeCode: String(localized: "Claude Code may read this folder. It can’t write to it.")
        case .claudeForMac: String(localized: "Claude for Mac doesn’t read folders on this Mac.")
        case .cursor: String(localized: "Cursor opens this folder. Atlas asks it only to read; Cursor’s settings decide the rest.")
        }
    }
}
