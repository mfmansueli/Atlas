//
//  MCPRefusedConnection.swift
//  Atlas
//

import Foundation

/// A request Atlas turned away because its token matched no pairing:
/// usually Claude Code still registered with a token from an older pairing
/// (or one the person revoked). Kept until an assistant connects with a
/// paired token again, so the overview can say "Claude Code can’t connect"
/// instead of "connected".
struct MCPRefusedConnection: Hashable, Sendable {
    var date: Date
    /// "Claude Code" when the request's User-Agent said so, else nil.
    var clientName: String?

    /// The client a User-Agent names, when it's one Atlas knows.
    static func clientName(userAgent: String?) -> String? {
        guard let agent = userAgent?.lowercased(), !agent.isEmpty else { return nil }
        if agent.contains("claude-code") || agent.contains("claude-cli") || agent.contains("claude code") {
            return MCPClientKind.claudeCode.title
        }
        if agent.contains("cursor") { return MCPClientKind.cursor.title }
        if agent.contains("codex") { return MCPClientKind.codex.title }
        return nil
    }
}
