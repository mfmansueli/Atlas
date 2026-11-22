//
//  AssistantsAdvancedSection.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Advanced (`set-assistants-adv`), hidden until Show: connections on or
/// off with the server's address, the one line to paste for any other
/// assistant (the bridge with a token made for it), Pair Assistant… for
/// the other kinds, and the assistants paired that way, each with
/// Disconnect….
struct AssistantsAdvancedSection: View {
    @Binding var isExpanded: Bool
    let onPair: () -> Void

    @Environment(MCPServerController.self) private var server

    var body: some View {
        Section {
            HStack(spacing: Spacing.medium) {
                SettingsRowLabel(title: "Advanced", caption: String(localized: "Turn connections off, or set up another assistant by hand."))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(isExpanded ? String(localized: "Hide") : String(localized: "Show")) {
                    withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() }
                }
                .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))
                .accessibilityIdentifier("settings.ai.advanced")
            }
            if isExpanded {
                Toggle(isOn: Binding(get: { server.isEnabled }, set: server.setEnabled)) {
                    SettingsRowLabel(title: "Let assistants connect", caption: serverText)
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.ai.server")
                byHand
                ForEach(otherClients) { client in
                    PairedClientRow(client: client, status: server.status(of: client)) {
                        server.revoke(client.id)
                    }
                }
            }
        }
    }

    private var serverText: String {
        server.isEnabled
            ? String(localized: "On · only on this Mac, at \(server.address), and only while Atlas is open")
            : String(localized: "Off. Paired assistants stay paired, and can’t connect.")
    }

    /// Assistants Connect doesn't list: Codex and other MCP clients.
    private var otherClients: [MCPPairedClient] {
        server.pairedClients.filter { ConnectableAssistant(clientKind: $0.kind) == nil }
    }

    // MARK: - By hand

    private var byHand: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                SettingsRowLabel(
                    title: "Another assistant, by hand",
                    caption: String(localized: """
                    For any app that supports MCP: in its MCP settings, add a server named “atlas” with this command, then \
                    restart it.
                    """)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Pair Assistant…", systemImage: "plus", action: onPair)
                    .controlSize(.small)
                    .disabled(!server.isRunning)
                    .accessibilityIdentifier("settings.ai.pair")
            }
            HStack(spacing: Spacing.small) {
                Text(verbatim: line ?? "\"\(server.bridgePath)\" --token …")
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.small)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .accessibilityIdentifier("settings.ai.byHandLine")
                Button(line == nil ? String(localized: "Copy") : String(localized: "Copied ✓"), action: copy)
                    .controlSize(.small)
                    .disabled(!server.isRunning)
                    .accessibilityIdentifier("settings.ai.byHandCopy")
            }
            Text(server.isRunning
                ? String(localized: "Copy makes the token for that assistant alone. It’s paired under its own name when it first connects.")
                : String(localized: "Turn on connections to copy the line with its token."))
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The bridge with the token Copy made: whatever connects with it is
    /// paired under the name it sends.
    private var line: String? {
        guard let pairing = server.pendingPairing, pairing.kind == .other, pairing.isWaiting, !pairing.isConnected else { return nil }
        return "\"\(server.bridgePath)\" --token \(pairing.token)"
    }

    private func copy() {
        if line == nil {
            server.beginPairing(kind: .other)
            server.markPairingCopied()
        }
        guard let line else { return }
        AssistantConnector.shared.copy(line)
    }
}
