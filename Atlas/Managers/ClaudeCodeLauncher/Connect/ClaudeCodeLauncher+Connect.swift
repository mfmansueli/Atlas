//
//  ClaudeCodeLauncher+Connect.swift
//  Atlas
//

import Foundation
import Synchronization

/// Connect for Claude Code: Atlas adds itself to the person's own Claude
/// Code, for every project, as the pairing sheet's command did. Claude
/// Code keeps its MCP servers in `~/.claude.json`, which the sandbox can't
/// write and which only `claude mcp` should; the helper runs `claude mcp
/// remove` and `claude mcp add --scope user` outside the sandbox, so
/// nothing is pasted in Terminal.
extension ClaudeCodeLauncher {
    /// Registers the stdio bridge with `token`. Returns why it couldn't,
    /// nil once Claude Code has it.
    func registerAtlas(token: String, bridgePath: String) async -> String? {
        if helper == .unknown || helper == .checking { await refreshHelper() }
        guard canStart, let helperURL, runner.exists(helperURL) else { return helper.title }
        let server = MCPEndpoint.serverName
        // An older entry, whose token Atlas would refuse, goes first.
        _ = await runClaude(["mcp", "remove", server, "--scope", "user"], helperURL: helperURL)
        let added = await runClaude(["mcp", "add", "--scope", "user", server, "--", bridgePath, "--token", token], helperURL: helperURL)
        guard added.status == 0 else {
            return added.lastLine ?? String(localized: "Claude Code didn’t add Atlas.")
        }
        return nil
    }

    /// Disconnect…: takes Atlas's entry out of Claude Code, when the helper
    /// is there.
    func unregisterAtlas() async {
        guard let helperURL, runner.exists(helperURL) else { return }
        _ = await runClaude(["mcp", "remove", MCPEndpoint.serverName, "--scope", "user"], helperURL: helperURL)
    }

    /// `claude <arguments>` in the home folder, through the helper's `run`.
    private func runClaude(_ arguments: [String], helperURL: URL) async -> (status: Int32?, lastLine: String?) {
        let lines = Mutex<[String]>([])
        let status = Mutex<Int32?>(nil)
        let exit = await runner.run(helperURL, arguments: ["run", ProjectFolderPath.home, "--"] + arguments) { line in
            if let code = ClaudeCodeHelperScript.exitStatus(in: line) {
                status.withLock { $0 = code }
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.withLock { $0.append(line) }
            }
        }
        let code = status.withLock { $0 } ?? (exit.taskError == nil ? 0 : nil)
        return (code, lines.withLock { $0.last } ?? exit.lastErrorLine ?? exit.taskError)
    }
}
