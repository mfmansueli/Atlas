//
//  EnvironmentValues+ChatCornerRoom.swift
//  Atlas
//

import SwiftUI

extension EnvironmentValues {
    /// The room a page leaves at its bottom edge for the assistant chat in
    /// the corner (`AssistantChatRoom.pageRoom` in an app's workspace),
    /// so its last content or a bar there isn't covered by the pill. Pages
    /// take it with `leavesChatRoom(_:)`. 0 where there's no chat: sheets,
    /// previews and DEBUG hosts.
    @Entry var chatCornerRoom: CGFloat = 0
}
