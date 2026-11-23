//
//  PrivacyAssistantStatusLine.swift
//  Atlas
//

import SwiftUI

/// "Claude Code connected · ~/Developer/Lumen · via Atlas’s local MCP
/// server", or that none is, with Settings….
struct PrivacyAssistantStatusLine: View {
    let session: MCPClientSession?
    let isEnabled: Bool
    let appName: String

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.small) {
            Circle()
                .fill(session == nil ? Palette.label3 : Palette.ok)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session == nil {
                SettingsLink {
                    Text("Settings…")
                }
                .controlSize(.regular)
                .accessibilityIdentifier("appInformation.appPrivacy.settings")
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.assistantStatus")
    }

    private var text: String {
        if let session {
            let folder = session.workingDirectory.map { " · \($0)" } ?? ""
            return String(localized: "\(session.displayName) connected\(folder) · via Atlas’s local MCP server")
        }
        guard isEnabled else {
            return String(localized: "No assistant connected. Turn on the local server in Settings, then connect Claude Code from \(appName)’s folder.")
        }
        return String(localized: "No assistant connected. The local server is on; connect Claude Code from \(appName)’s folder.")
    }
}
