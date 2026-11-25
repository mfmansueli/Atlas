//
//  WorkspacePageActionItem.swift
//  Atlas
//

import SwiftUI

/// The section's page action in the toolbar (board 80), where the
/// Autopilot button was: a glass capsule with its plus and title (README-DS
/// §4, Toolbar), “…” because it opens a sheet. Off while the section can't
/// run it, with the reason as its tooltip.
struct WorkspacePageActionItem: View {
    let action: WorkspacePageAction
    var state: WorkspacePageActionState = .enabled
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            Label(action.title, systemImage: action.systemImage)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.glass)
        .disabled(!state.isEnabled)
        .help(state.reason ?? action.help)
        // The title changes with the section: New Page… is narrower than
        // Add Subscription….
        .toolbarItemFit(action.title)
        // The title truncates before it squeezes this.
        .reportsToolbarRoom(.pageAction)
        .accessibilityIdentifier(action.identifier)
    }
}

#Preview {
    if let action = AppWorkspaceSection.productPages.pageAction {
        WorkspacePageActionItem(action: action) {}
            .padding()
    }
}
