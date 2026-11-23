//
//  ComplianceAskButton.swift
//  Atlas
//

import SwiftUI

/// "Ask Claude Code…" on App Compliance: suggests the answers the project
/// can show, which wait on their cards for the person.
struct ComplianceAskButton: View {
    let app: StoreApp

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: ComplianceAskPrompt.purpose,
            prompt: ComplianceAskPrompt.text(app: app.name),
            help: { client in String(localized: "Asks \(client) to suggest answers from the project") },
            explanation: { client in
                String(localized: """
                \(client) reads \(app.name)’s project and suggests answers. Accept each, then enter it in App Store \
                Connect.
                """)
            },
            identifier: "appInformation.compliance.ask"
        )
    }
}
