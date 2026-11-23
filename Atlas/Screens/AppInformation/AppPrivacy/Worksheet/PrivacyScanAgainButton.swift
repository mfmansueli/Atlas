//
//  PrivacyScanAgainButton.swift
//  Atlas
//

import SwiftUI

/// Scan the Code Again…: asks the assistant to read the project again and
/// send new App Privacy answers, which arrive on their rows in purple.
/// "Scan the Code…" before any scan (a worksheet started by hand).
struct PrivacyScanAgainButton: View {
    let viewModel: AppPrivacyViewModel

    var body: some View {
        let app = viewModel.app
        let hasScanned = viewModel.worksheet.lastScan != nil
        ClaudeCodeAskButton(
            app: app,
            purpose: .privacyScan,
            prompt: viewModel.scanPrompt,
            help: { client in
                String(localized: "Ask \(client) to read \(app.name)’s project and suggest App Privacy answers", comment: "kind:tooltip")
            },
            explanation: { client in
                String(localized: "\(client) reads \(app.name)’s project again. Changes are marked in purple here.", comment: "kind:description")
            },
            identifier: "appInformation.appPrivacy.scanAgain",
            title: { _ in
                hasScanned
                    ? String(localized: "Scan the Code Again…", comment: "kind:button")
                    : String(localized: "Scan the Code…", comment: "kind:button")
            },
            subject: String(localized: "App Privacy · the code", comment: "kind:other"),
            done: { client in
                String(localized: "\(client) read the project again. Changes are marked in purple in App Privacy.", comment: "kind:toast")
            }
        )
    }
}
