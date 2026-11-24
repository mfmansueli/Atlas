//
//  MCPBridgeLaunch.swift
//  atlas-mcp
//

import Foundation

/// What opening Atlas did when its MCP server didn't answer.
enum MCPBridgeLaunch: Equatable, Sendable {
    /// Atlas was opened just now, or was already starting: its server is on
    /// its way, so the request waits for it.
    case starting
    /// Atlas has been open a while: its server is off, and waiting wouldn't
    /// bring it.
    case running
    /// Atlas couldn't be opened, and why.
    case unavailable(String)
}
