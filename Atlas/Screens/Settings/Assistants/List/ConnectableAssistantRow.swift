//
//  ConnectableAssistantRow.swift
//  Atlas
//

import AppKit
import SwiftUI

/// One assistant in "Connect an assistant" (board 48): its tile, name and
/// state, and the one button that fits: Connect when it's on this Mac,
/// Disconnect… (asked in place) once connected, Get … when it isn't
/// installed. Just connected, it offers what to try and Send a Test
/// Suggestion (`set-assistants-done`).
struct ConnectableAssistantRow: View {
    let assistant: ConnectableAssistant
    let onConnect: () -> Void

    @Environment(MCPServerController.self) private var server
    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(AssistantConnector.self) private var connector
    @State private var isAskingToDisconnect = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                AssistantLogo(assistant: assistant)
                VStack(alignment: .leading, spacing: 2) {
                    Text(assistant.title)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(isConnected && server.isEnabled ? Palette.done : Palette.label2)
                        .accessibilityIdentifier("settings.ai.assistant.\(assistant.rawValue).status")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            if let fresh, !isAskingToDisconnect { tryIt(fresh) }
            if isAskingToDisconnect { askToDisconnect }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.ai.assistant.\(assistant.rawValue)")
    }

    private var client: MCPPairedClient? {
        server.pairedClient(of: assistant.clientKind)
    }

    private var isConnected: Bool {
        client != nil
    }

    private var fresh: AssistantConnector.FreshConnection? {
        guard isConnected, let fresh = connector.fresh, fresh.assistant == assistant else { return nil }
        return fresh
    }

    // MARK: - State

    /// "Connected · last used today at 10:43", "Found on this Mac".
    private var statusText: String {
        guard let client else {
            return connector.isInstalled(assistant, launcher: launcher)
                ? String(localized: "Found on this Mac")
                : String(localized: "Not installed on this Mac")
        }
        guard server.isEnabled else { return String(localized: "Can’t connect while connections are off") }
        if let fresh {
            guard let folder = fresh.folder else { return String(localized: "Connected just now") }
            return String(localized: "Connected just now · reads \(ProjectFolderPath.abbreviated(folder))")
        }
        return String(localized: "Connected · \(Self.lastUsed(client.lastSeenAt))")
    }

    /// "last used today at 10:43", "last used Oct 22", "not used yet".
    static func lastUsed(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let date else { return String(localized: "not used yet") }
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "last used today at \(date.formatted(date: .omitted, time: .shortened))")
        }
        return String(localized: "last used \(date.formatted(.dateTime.month(.abbreviated).day()))")
    }

    @ViewBuilder
    private var trailing: some View {
        if isConnected {
            HStack(spacing: Spacing.small) {
                Label("Connected", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.done)
                    .labelStyle(.titleAndIcon)
                Button("Disconnect…") { isAskingToDisconnect = true }
                    .disabled(isAskingToDisconnect)
                    .accessibilityLabel(Text("Disconnect \(assistant.title)…"))
                    .accessibilityIdentifier("settings.ai.disconnect.\(assistant.rawValue)")
            }
        } else if connector.isInstalled(assistant, launcher: launcher) {
            Button("Connect", action: onConnect)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Text("Connect \(assistant.title)"))
                .accessibilityIdentifier("settings.ai.connect.\(assistant.rawValue)")
        } else {
            Button("Get \(assistant.productName)…") { NSWorkspace.shared.open(assistant.downloadURL) }
                .accessibilityIdentifier("settings.ai.get.\(assistant.rawValue)")
        }
    }

    // MARK: - Just connected

    private func tryIt(_ fresh: AssistantConnector.FreshConnection) -> some View {
        let test = connector.tests[assistant]
        return HStack(spacing: Spacing.medium) {
            Text(tryText(fresh, test: test))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settings.ai.try.\(assistant.rawValue).text")
            Button(testTitle(test)) {
                Task { await connector.sendTest(assistant, appID: fresh.appID, appName: fresh.appName, launcher: launcher) }
            }
            .controlSize(.small)
            .disabled(test == .sending || test == .arrived || test == .copied)
            .accessibilityIdentifier("settings.ai.test.\(assistant.rawValue)")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.ai.try.\(assistant.rawValue)")
    }

    private func tryText(_ fresh: AssistantConnector.FreshConnection, test: AssistantConnector.TestState?) -> String {
        switch test {
        case nil:
            let question = AssistantConnectPrompts.subtitleQuestion(appName: fresh.appName)
            return String(localized: "Try it: ask \(assistant.title) “\(question)”, or send a test from here.")
        case .sending:
            return String(localized: "\(assistant.title) is writing a subtitle for \(fresh.appName)…")
        case .arrived:
            return String(localized: "A test suggestion arrived in Store Page, marked as a test. It works.")
        case .copied:
            return String(localized: "The test is on the clipboard. Paste it into \(assistant.title): its suggestion arrives in Store Page, marked as a test.")
        case let .failed(reason):
            return String(localized: "The test didn’t arrive: \(reason)")
        }
    }

    private func testTitle(_ test: AssistantConnector.TestState?) -> String {
        switch test {
        case .sending: String(localized: "Sending…")
        case .arrived: String(localized: "Sent ✓")
        case .copied: String(localized: "Copied ✓")
        case nil, .failed: String(localized: "Send a Test Suggestion")
        }
    }

    // MARK: - Disconnect…

    private var askToDisconnect: some View {
        HStack(spacing: Spacing.medium) {
            Text("\(assistant.title) stops suggesting. What it already suggested stays in Atlas.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel") { isAskingToDisconnect = false }
                .controlSize(.small)
                .accessibilityIdentifier("settings.ai.disconnect.\(assistant.rawValue).cancel")
            Button("Disconnect", role: .destructive) {
                isAskingToDisconnect = false
                connector.disconnect(assistant, server: server, launcher: launcher)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(Palette.dangerMark)
            .accessibilityIdentifier("settings.ai.disconnect.\(assistant.rawValue).confirm")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.dangerTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.ai.disconnect.\(assistant.rawValue).ask")
    }
}
