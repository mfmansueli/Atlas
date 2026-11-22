//
//  MCPServerController+Connect.swift
//  Atlas
//

import Foundation

/// One-click Connect (Settings → AI Assistants): the pairing an assistant
/// connects as, made without the pairing sheet, and whether it's
/// connected.
extension MCPServerController {
    /// The pairing of `kind` Connect uses: the newest one with a token, else
    /// a new one (its token saved like a pairing's). Nil when the token
    /// couldn't be saved.
    func connectionCredentials(for kind: MCPClientKind) -> (clientID: MCPPairedClient.ID, token: String)? {
        if let client = pairedClients.last(where: { $0.kind == kind }) {
            if let token = tokens[client.id] { return (client.id, token) }
            // Paired without a token Atlas can read any more: a new one.
            let token = MCPAccessToken.generate()
            guard save(token, for: client) else { return nil }
            return (client.id, token)
        }
        let client = MCPPairedClient(id: UUID(), kind: kind, name: kind.title, pairedAt: now())
        let token = MCPAccessToken.generate()
        guard save(token, for: client) else { return nil }
        pairedClients.append(client)
        savePairedClients()
        return (client.id, token)
    }

    /// The pairing Connect made for `kind`, if any.
    func pairedClient(of kind: MCPClientKind) -> MCPPairedClient? {
        pairedClients.last { $0.kind == kind }
    }

    /// Whether `clientID` has a session open now.
    func hasSession(for clientID: MCPPairedClient.ID) -> Bool {
        sessions.contains { $0.pairedClientID == clientID }
    }

    /// Disconnect…: every pairing of `kind` is revoked.
    func disconnectAll(of kind: MCPClientKind) {
        for client in pairedClients where client.kind == kind {
            revoke(client.id)
        }
    }

    private func save(_ token: String, for client: MCPPairedClient) -> Bool {
        do {
            try secrets.setSecret(token, named: client.secretName)
        } catch {
            record(client: client.name, tool: "—", target: "", outcome: .refused, reason: error.localizedDescription)
            return false
        }
        tokens[client.id] = token
        return true
    }
}
