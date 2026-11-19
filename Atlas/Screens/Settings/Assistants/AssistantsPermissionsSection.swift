//
//  AssistantsPermissionsSection.swift
//  Atlas
//

import SwiftUI

/// Settings → AI Assistants: what assistants may suggest, a switch each,
/// and what they never can, as locked rows instead of left out.
struct AssistantsPermissionsSection: View {
    let server: MCPServerController

    var body: some View {
        Section("Assistants may suggest") {
            LabeledContent {
                Text("Always")
                    .foregroundStyle(Palette.label2)
            } label: {
                SettingsRowLabel(title: "Read apps, listings, prices and app information", caption: String(localized: "On while the server runs."))
            }
            .accessibilityIdentifier("settings.ai.can")
            ForEach(MCPProposalKind.allCases) { kind in
                Toggle(isOn: Binding(get: { server.allows(kind) }, set: { server.setAllowed(kind, $0) })) {
                    SettingsRowLabel(title: LocalizedStringKey(kind.title), caption: kind.caption)
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.ai.allow.\(kind.rawValue)")
            }
        }
        Section("Assistants never") {
            SettingsLockedRow(title: "Push anything to App Store Connect", trailing: nil)
                .accessibilityIdentifier("settings.ai.cannot")
            SettingsLockedRow(title: "Accept a suggestion for you", trailing: nil)
            SettingsLockedRow(title: "See your .p8 key, or an API key", trailing: nil)
        }
    }
}
