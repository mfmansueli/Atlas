//
//  AssistantToolbarIndicator+Debug.swift
//  Atlas
//

#if DEBUG
import Foundation

@MainActor
extension AssistantToolbarIndicator {
    /// DEBUG scenes set it to open the popover once the indicator appears
    /// (design `prop-list`).
    static var debugShowsPopover = false
}
#endif
