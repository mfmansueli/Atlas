//
//  AutopilotBarFooter.swift
//  Atlas
//

import SwiftUI

/// The open bar's last line (board 80): who answers and the safety line,
/// with Settings…; without an assistant, “No assistant connected” and
/// Connect….
struct AutopilotBarFooter: View {
    /// “Claude Code · connected to Lumen”; nil without an assistant.
    let connection: String?
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            AssistantStatusDot(status: connection == nil ? .notSetUp : .connected(client: ""))
            Group {
                if let connection {
                    Text("\(connection) · changes come back as suggestions", comment: "kind:footnote · the open Autopilot bar")
                } else {
                    Text("No assistant connected", comment: "kind:footnote · the open Autopilot bar")
                }
            }
            .atlasTextStyle(.subheadline)
            .foregroundStyle(Palette.label2)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            if connection == nil {
                Button(String(localized: "Connect…", comment: "kind:button"), action: onConnect)
                    .plainButton()
                    .fixedSize()
                    .accessibilityIdentifier("autopilotBar.footer.connect")
            } else {
                SettingsLink {
                    Text("Settings…", comment: "kind:button")
                }
                .buttonStyle(.link)
                .fixedSize()
                .accessibilityIdentifier("autopilotBar.footer.settings")
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilotBar.footer")
    }
}
