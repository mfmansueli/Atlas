//
//  AccountCommands.swift
//  Atlas
//

import SwiftUI

/// "Add Another Key…" in the Atlas menu, under Settings….
struct AccountCommands: Commands {
    let session: AppSession

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Add Another Key…") { session.isAddingKey = true }
                // The connect screen already asks for the first key.
                .disabled(session.keys.isEmpty)
        }
    }
}
