//
//  WorkspaceAutopilotBar+Debug.swift
//  Atlas
//

#if DEBUG
import Foundation

@MainActor
extension WorkspaceAutopilotBar {
    /// DEBUG scenes set it to open the assistant's status popover once the
    /// bar appears (design `prop-list`).
    static var debugShowsPopover = false
}
#endif
