//
//  EncryptionKeyAskButton.swift
//  Atlas
//

import SwiftUI

/// Add It to the Project (or Try Again, Check in the Project…): Claude
/// Code adds the export compliance key to the app target with the settled
/// answer and reports it here with `report_encryption_key`. Without a
/// settled answer it's a plain disabled button: the card says why.
struct EncryptionKeyAskButton: View {
    let app: StoreApp
    /// Nil while the answer isn't settled.
    let answer: EncryptionKeyAnswer?
    let title: String

    var body: some View {
        if let answer {
            ClaudeCodeAskButton(
                app: app,
                purpose: EncryptionKeyAskPrompt.purpose,
                prompt: EncryptionKeyAskPrompt.text(app: app.name, appID: app.id, bundleID: app.bundleID, answer: answer),
                help: { client in String(localized: "Ask \(client) to add \(EncryptionKeyAnswer.key) = \(answer.value.rawValue) to \(app.name)’s project") },
                explanation: { client in
                    String(localized: """
                    \(client) finds \(app.name)’s app target and adds \(EncryptionKeyAnswer.key) = \(answer.value.rawValue) the way \
                    the project is set up, then says here where. It commits only when the project’s instructions say so, and \
                    never pushes or uploads: builds you upload from then on answer the question.
                    """)
                },
                identifier: "appInformation.export.addKey",
                title: { _ in title },
                subject: String(localized: "Export compliance key"),
                done: { client in String(localized: "\(client) finished with the export compliance key. It’s on Export Compliance.") }
            )
        } else {
            Button(title) {}
                .disabled(true)
                .accessibilityIdentifier("appInformation.export.addKey")
        }
    }
}
