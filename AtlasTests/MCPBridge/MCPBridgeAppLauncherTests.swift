//
//  MCPBridgeAppLauncherTests.swift
//  AtlasTests
//

import Foundation
import Testing

@Suite("MCPBridgeAppLauncher")
struct MCPBridgeAppLauncherTests {
    @Test func itOpensTheAppTheBridgeIsIn() {
        let launcher = MCPBridgeAppLauncher(executableURL: URL(filePath: "/Applications/Atlas.app/Contents/MacOS/atlas-mcp"))
        #expect(launcher.appURL?.lastPathComponent == "Atlas.app")
        #expect(launcher.appURL?.deletingLastPathComponent().lastPathComponent == "Applications")
    }

    @Test func aBridgeOutsideAnAppFallsBackToLaunchServices() {
        #expect(MCPBridgeAppLauncher(executableURL: URL(filePath: "/usr/local/bin/atlas-mcp")).appURL == nil)
        #expect(MCPBridgeAppLauncher(executableURL: nil).appURL == nil)
    }
}
