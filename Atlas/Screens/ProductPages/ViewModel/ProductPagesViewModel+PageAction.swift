//
//  ProductPagesViewModel+PageAction.swift
//  Atlas
//

import Foundation

/// New Page… in the toolbar (board 80).
extension ProductPagesViewModel {
    /// Gone while a page's editor is open; off while reading, at Apple's
    /// limit, offline and with a key that can't change pages.
    var pageActionState: WorkspacePageActionState {
        if selectedPageID != nil { return .hidden }
        return state.value != nil && canMakePages ? .enabled : .disabled(reason: nil)
    }

    /// New Page…'s sheet, when a page can be made.
    func startPageAction() {
        guard pageActionState.isEnabled else { return }
        isNewPagePresented = true
    }
}
