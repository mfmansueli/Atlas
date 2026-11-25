//
//  WorkspacePageActionReporter.swift
//  Atlas
//

import SwiftUI

/// Tells the window's toolbar how the section's page action shows
/// (`WorkspaceNavigator.pageActionStates`), whenever it changes, and
/// forgets it when the section goes, so a section shown again starts on.
struct WorkspacePageActionReporter: ViewModifier {
    let state: WorkspacePageActionState
    let section: AppWorkspaceSection

    /// Nil in previews without the main window.
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?

    func body(content: Content) -> some View {
        content
            .onChange(of: state, initial: true) { _, state in
                navigator?.setPageActionState(state, for: section)
            }
            .onDisappear { navigator?.setPageActionState(nil, for: section) }
    }
}

extension View {
    /// Reports how `section`'s page action in the toolbar shows.
    func reportsPageAction(_ state: WorkspacePageActionState, for section: AppWorkspaceSection) -> some View {
        modifier(WorkspacePageActionReporter(state: state, section: section))
    }
}
