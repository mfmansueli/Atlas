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
            help: { client in String(localized: "Ask \(client) to suggest App Compliance answers from the project") },
            explanation: { client in
                String(localized: """
                \(client) reads \(app.name)’s project and suggests answers. Each one waits on its card until you \
                accept it; you still enter them in App Store Connect.
                """)
            },
            identifier: "appInformation.compliance.ask"
        )
    }
}
