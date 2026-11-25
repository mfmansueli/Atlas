//
//  View+ChatRoom.swift
//  Atlas
//

import SwiftUI

extension View {
    /// The page's last content, or its bar, ends above the chat's pill in
    /// the corner (board 69). Put it on the page's main vertical scroll
    /// view (the default), or on a page that fills the height with a bar,
    /// boxes or a table on its bottom edge (`.bottomEdge`). Each column
    /// that reaches the bottom edge takes its own. Never on a horizontal
    /// scroller, a text editor or a sheet.
    func leavesChatRoom(_ placement: ChatRoomPlacement = .scrollContent) -> some View {
        modifier(ChatRoomModifier(placement: placement))
    }
}
