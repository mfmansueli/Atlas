//
//  ChatRoomModifier.swift
//  Atlas
//

import SwiftUI

/// Leaves the chat's pill its room at the bottom of a page's container,
/// the way `placement` takes it. Reads `chatCornerRoom`, so it's 0
/// wherever the pill isn't shown: sheets, previews and DEBUG hosts. What's
/// inside already ends above the pill, so it gets no room of its own: a
/// product page's offer list doesn't leave it twice.
struct ChatRoomModifier: ViewModifier {
    let placement: ChatRoomPlacement

    @Environment(\.chatCornerRoom) private var room

    func body(content: Content) -> some View {
        let inside = content.environment(\.chatCornerRoom, 0)
        switch placement {
        case .scrollContent:
            inside.contentMargins(.bottom, placement.contentMargin(room: room), for: .scrollContent)
        case .bottomEdge:
            inside.padding(.bottom, placement.padding(room: room))
        }
    }
}
