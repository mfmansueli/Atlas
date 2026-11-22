//
//  AssistantsDebugState.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Puts the MCP server into one of the design's states for DEBUG scenes:
/// off, pairing (the command copied, waiting for the client), paired
/// assistants (one connected in Lumen's folder, one idle), one
/// disconnected, or a log with refused calls; for the overview's card,
/// Claude Code refused for an old token, connected only in Tempo's folder,
/// or connected in a folder Lumen wasn't given yet. Nothing listens on a
/// port.
enum AssistantsDebugState {
    case off
    case pairing
    case paired
    case disconnected
    case log
    /// Paired, nothing connected, and a request with an old token turned
    /// away two minutes ago.
    case refused
    /// Claude Code works in Tempo Metronome's folder only.
    case elsewhere
    /// Claude Code works in ~/Developer/Lumen, but Lumen has no folder yet.
    case unattached
    /// The server on, nothing connected yet (board 48's Connect).
    case connectable
    /// Claude Code connected a moment ago through Connect, in Lumen's
    /// folder; nothing else.
    case justConnected

    @MainActor
    func apply(to server: MCPServerController) {
        guard self != .off else { return }
        server.setEnabled(true)
        switch self {
        case .off, .connectable:
            break
        case .pairing:
            server.beginPairing(kind: .claudeCode)
            server.markPairingCopied()
        case .paired:
            server.restorePairings([Self.claudeCode, Self.cursor], tokens: [:])
            server.sessions = [Self.session(lastActivity: Self.today(10, 43))]
            Self.giveFolders(on: server)
        case .refused:
            server.restorePairings([Self.claudeCode], tokens: [:])
            server.refusedConnection = MCPRefusedConnection(date: .now.addingTimeInterval(-120), clientName: MCPClientKind.claudeCode.title)
            Self.giveFolders(on: server)
        case .elsewhere:
            server.restorePairings([Self.claudeCode], tokens: [:])
            var session = Self.session(lastActivity: .now.addingTimeInterval(-60))
            session.workingDirectory = "~/Developer/Tempo"
            server.sessions = [session]
            Self.giveFolders(on: server)
        case .unattached:
            server.restorePairings([Self.claudeCode], tokens: [:])
            server.sessions = [Self.session(lastActivity: .now.addingTimeInterval(-60))]
        case .justConnected:
            var client = Self.claudeCode
            client.pairedAt = .now.addingTimeInterval(-20)
            client.lastSeenAt = .now.addingTimeInterval(-5)
            server.restorePairings([client], tokens: [:])
            server.sessions = [Self.session(lastActivity: .now.addingTimeInterval(-5))]
            Self.giveFolders(on: server)
        case .disconnected:
            var client = Self.claudeCode
            client.lastSeenAt = Self.today(10, 44)
            server.restorePairings([client], tokens: [:])
            server.seenThisLaunch = [client.id]
        case .log:
            server.restorePairings([Self.claudeCode], tokens: [:])
            server.sessions = [Self.session(lastActivity: Self.today(11, 42))]
            Self.writeLog(on: server)
        }
    }

    @MainActor
    private static func writeLog(on server: MCPServerController) {
        for line in logLines.reversed() {
            server.record(client: line.client, tool: line.tool, target: line.target, outcome: line.outcome, reason: line.reason, at: line.date)
        }
    }

    static let claudeCodeID = UUID(uuidString: "6C1E7C3A-2B11-4D0E-9C55-0A4F1B2C3D01") ?? UUID()

    /// Lumen's project folder is ~/Developer/Lumen and Tempo's
    /// ~/Developer/Tempo, unless a scene set up the app itself (`cc-settings`
    /// leaves Tempo's for Choose…).
    @MainActor
    private static func giveFolders(on server: MCPServerController) {
        guard let launcher = server.launcher else { return }
        let folders: [(StoreApp.ID, String, String)] = [
            (DebugFixtures.AppID.lumen, "Lumen Journal", "~/Developer/Lumen"),
            (DebugFixtures.AppID.tempo, "Tempo Metronome", "~/Developer/Tempo"),
        ]
        let known = Set(launcher.knownApps.map(\.id))
        for (id, name, folder) in folders where launcher.projectFolder(for: id) == nil && !known.contains(id) {
            launcher.setProjectFolder(ProjectFolderPath.expanded(folder), for: id)
            launcher.rememberApp(id, name: name)
        }
    }

    static var claudeCode: MCPPairedClient {
        MCPPairedClient(
            id: claudeCodeID,
            kind: .claudeCode,
            name: "Claude Code",
            pairedAt: today(9, 30),
            lastSeenAt: today(10, 43),
            workingDirectory: "~/Developer/Lumen"
        )
    }

    static var cursor: MCPPairedClient {
        let october22 = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 16)) ?? .now
        return MCPPairedClient(
            id: UUID(uuidString: "6C1E7C3A-2B11-4D0E-9C55-0A4F1B2C3D02") ?? UUID(),
            kind: .cursor,
            name: "Cursor",
            pairedAt: october22,
            lastSeenAt: october22,
            workingDirectory: "~/Developer/Lumen-web"
        )
    }

    private static func session(lastActivity: Date) -> MCPClientSession {
        MCPClientSession(
            id: "debug-session",
            pairedClientID: claudeCodeID,
            clientName: "claude-code",
            clientVersion: "2.1.0",
            displayName: "Claude Code",
            protocolVersion: MCPProtocolVersion.latest,
            supportsRoots: true,
            connectedAt: today(10, 40),
            lastActivity: lastActivity,
            hasOpenStream: true,
            workingDirectory: "~/Developer/Lumen"
        )
    }

    private static func today(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    /// Newest first, a few minutes apart.
    private static var logLines: [MCPLogEntry] {
        [
            line(42, "propose_listing_text", "Lumen Journal · ko · Description", .proposed),
            line(41, "propose_listing_text", "Lumen Journal · de-DE · Subtitle", .refused, "34 characters; the limit is 30. Shorten it and propose again."),
            line(39, "propose_prices", "Tempo Metronome · Annual", .refused, "Tempo is set to Keep my prices, so price proposals are off for this app."),
            line(36, "propose_prices", "Lumen Journal · Annual · BR", .refused, "R$ 112,00 isn’t a price point. Nearest: R$ 110,00 or R$ 114,90."),
            line(31, "list_missing_translations", "Lumen Journal · version 1.4", .read),
            line(30, "list_apps", "Northpier Studio · 6 apps", .read),
        ]
    }

    private static func line(_ minute: Int, _ tool: String, _ target: String, _ outcome: MCPCallOutcome, _ reason: String? = nil) -> MCPLogEntry {
        MCPLogEntry(date: today(11, minute), client: "Claude Code", tool: tool, target: target, outcome: outcome, reason: reason)
    }
}
#endif
