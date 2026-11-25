//
//  InAppEventsViewModel+PageAction.swift
//  Atlas
//

import Foundation

/// New Event… in the toolbar (board 80).
extension InAppEventsViewModel {
    /// Off until the events are read.
    var pageActionState: WorkspacePageActionState {
        state.value != nil ? .enabled : .disabled(reason: nil)
    }

    /// New Event…'s sheet, over the gallery or the open event.
    func startPageAction() {
        guard pageActionState.isEnabled else { return }
        isNewEventPresented = true
    }
}
