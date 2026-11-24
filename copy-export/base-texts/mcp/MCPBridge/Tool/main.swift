//
//  main.swift
//  atlas-mcp
//

import Foundation

// The stdio bridge in Atlas.app/Contents/MacOS that Claude Code, Claude
// Desktop and Codex launch: JSON-RPC lines on stdin go to Atlas's local MCP
// server with the pairing token, and its replies, and what Atlas asks on the
// session's event stream, come back on stdout. When Atlas is closed, the
// bridge opens it. Diagnostics go to stderr, which clients keep in their logs.
// Everything written to stdout goes through the main actor, one line at a
// time.

func writeLine(_ line: String, to handle: FileHandle) {
    handle.write(Data((line + "\n").utf8))
}

let options: MCPBridgeOptions
do {
    options = try MCPBridgeOptions(arguments: Array(CommandLine.arguments.dropFirst()))
} catch .help {
    writeLine(MCPBridgeOptions.usage, to: .standardOutput)
    exit(EXIT_SUCCESS)
} catch {
    writeLine(error.message, to: .standardError)
    exit(64) // EX_USAGE
}

let bridge = MCPBridge(
    options: options,
    transport: MCPBridgeHTTPTransport(),
    launcher: MCPBridgeAppLauncher(),
    emit: { line in Task { @MainActor in writeLine(line, to: .standardOutput) } },
    log: { message in writeLine("atlas-mcp: \(message)", to: .standardError) }
)

do {
    for try await line in FileHandle.standardInput.bytes.lines where !line.isEmpty {
        for reply in await bridge.forward(line) {
            writeLine(reply, to: .standardOutput)
        }
    }
} catch {
    writeLine("atlas-mcp: stdin closed: \(error.localizedDescription)", to: .standardError)
}

await bridge.close()
