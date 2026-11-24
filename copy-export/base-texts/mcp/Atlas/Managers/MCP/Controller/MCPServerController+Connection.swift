//
//  MCPServerController+Connection.swift
//  Atlas
//

import Foundation

/// The assistant's connection as the app on screen sees it: the folders
/// its open sessions work in against the app's project folder, and a
/// refused token.
extension MCPServerController {
    /// What the overview's card and the popover say for `appID`, or nil
    /// with no assistant to describe.
    func connection(appID: StoreApp.ID, appName: String, launcher: ClaudeCodeLauncher?) -> AssistantConnection? {
        guard let client = assistantClient else { return nil }
        let pairings = pairings(of: client)
        let ids = Set(pairings.map(\.id)).union([client.id])
        let open = sessions.filter { ids.contains($0.pairedClientID) }
        let appFolder = launcher?.projectFolder(for: appID).map(displayFolder)
        let names = Dictionary((launcher?.knownApps ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let otherApps = (launcher?.projectFolders ?? [:])
            .filter { $0.key != appID }
            .sorted { $0.key < $1.key }
            .map { (folder: displayFolder($0.value), appName: names[$0.key]) }
        let canStart = launcher?.canStart == true
        let lastSeen = pairings.compactMap(\.lastSeenAt).max() ?? client.lastSeenAt
        let state = AssistantConnection.state(
            appFolder: appFolder,
            sessionFolders: open.map(\.workingDirectory),
            otherApps: otherApps,
            refused: refusedConnection,
            canStart: canStart,
            lastSeen: lastSeen
        )
        return AssistantConnection(
            clientName: client.name,
            appName: appName,
            appFolder: appFolder,
            state: state,
            editsDrafts: editsDrafts,
            lastCall: open.map(\.lastActivity).max() ?? lastSeen,
            startsRuns: canStart
        )
    }

    /// Every pairing of the same assistant. Pairing it again for another
    /// project keeps the earlier token working, so Claude Code in each
    /// project can hold a different one: Alba's kept the first while
    /// SimProps's setup made a second, and Alba's card said "connected to
    /// another project" because only the newest pairing's sessions counted.
    private func pairings(of client: MCPPairedClient) -> [MCPPairedClient] {
        pairedClients.filter { $0.kind == client.kind && $0.name == client.name }
    }

    /// "~/Projects/ios/Alba", without the trailing slash a folder URL's
    /// path keeps.
    private func displayFolder(_ path: String) -> String {
        let folder = ProjectFolderPath.abbreviated(path, home: homeDirectory)
        return folder.count > 1 && folder.hasSuffix("/") ? String(folder.dropLast()) : folder
    }
}
