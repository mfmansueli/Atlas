//
//  NominationsViewModel+PageAction.swift
//  Atlas
//

import Foundation

/// New Nomination… in the toolbar (board 80).
extension NominationsViewModel {
    /// Off until the nominations are read, and with a key that can't
    /// create them.
    var pageActionState: WorkspacePageActionState {
        guard state.value != nil else { return .disabled(reason: nil) }
        return keyCannotWrite
            ? .disabled(reason: String(localized: "This key can’t create nominations", comment: "kind:tooltip"))
            : .enabled
    }

    /// A new draft, open with nothing in it.
    func startPageAction() {
        guard pageActionState.isEnabled else { return }
        newNomination()
    }
}
