//
//  AccountCommands.swift
//  Atlas
//

import SwiftUI

/// "Add Another Key…" in the Atlas menu, under Settings…. In Free, with a
/// key saved already, it opens the paywall.
struct AccountCommands: Commands {
    let session: AppSession
    let pro: ProGate

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Add Another Key…", systemImage: "key") {
                pro.requireNewAccount(accountCount: session.keys.count) { session.isAddingKey = true }
            }
            // The connect screen already asks for the first key.
            .disabled(session.keys.isEmpty)
        }
    }
}
