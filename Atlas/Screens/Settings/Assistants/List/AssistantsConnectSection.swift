//
//  AssistantsConnectSection.swift
//  Atlas
//

import SwiftUI

/// "Connect an assistant" (board 48, November 22): the assistants this Mac
/// has, each with Connect, and the three steps while none is connected.
/// With connections turned off, the section says so first, with Turn On.
struct AssistantsConnectSection: View {
    let onConnect: (ConnectableAssistant) -> Void

    @Environment(MCPServerController.self) private var server

    var body: some View {
        Section {
            if !anyConnected { ConnectHowItWorks() }
            if !server.isEnabled { connectionsOff }
            ForEach(ConnectableAssistant.allCases) { assistant in
                ConnectableAssistantRow(assistant: assistant) { onConnect(assistant) }
            }
        } header: {
            Text("Connect an assistant")
        } footer: {
            Text("""
            Atlas connects the assistant for you. Assistants read and suggest, never see your .p8 key, and can’t push.
            """)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("settings.ai.assistants")
    }

    private var anyConnected: Bool {
        ConnectableAssistant.allCases.contains { server.pairedClient(of: $0.clientKind) != nil }
    }

    private var connectionsOff: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.warnMark)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connections are turned off")
                    .font(.callout.weight(.semibold))
                Text("Your assistants stay in the list, and can’t reach Atlas until you turn this on.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Turn On") { server.setEnabled(true) }
                .accessibilityIdentifier("settings.ai.turnOn")
        }
        .padding(Spacing.medium)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.ai.connectionsOff")
    }
}
