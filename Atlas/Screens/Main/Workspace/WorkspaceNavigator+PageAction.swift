//
//  WorkspaceNavigator+PageAction.swift
//  Atlas
//

import Foundation

/// The toolbar's page action (board 80): how it shows, and running it.
extension WorkspaceNavigator {
    /// How `section`'s page action shows; nil for a section without one.
    /// A section that hasn't reported yet has it on.
    func pageActionState(for section: AppWorkspaceSection) -> WorkspacePageActionState? {
        guard section.pageAction != nil else { return nil }
        return pageActionStates[section] ?? .enabled
    }

    /// Keeps what `section` reports; nil forgets it.
    func setPageActionState(_ state: WorkspacePageActionState?, for section: AppWorkspaceSection) {
        guard pageActionStates[section] != state else { return }
        pageActionStates[section] = state
    }

    /// The current section's page action, when it has one that's on: the
    /// section opens its sheet (`WorkspaceIntent.pageAction`).
    func runPageAction(appID: StoreApp.ID? = nil) {
        guard pageActionState(for: section)?.isEnabled == true else { return }
        open(section, intent: .pageAction, appID: appID)
    }
}
