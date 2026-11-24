//
//  MCPBridgeLauncher.swift
//  atlas-mcp
//

import Foundation

/// Opens Atlas when its MCP server can't be reached: `MCPBridgeAppLauncher`
/// in the tool, a fake in tests.
protocol MCPBridgeLauncher: Sendable {
    func openAtlas() async -> MCPBridgeLaunch
}
