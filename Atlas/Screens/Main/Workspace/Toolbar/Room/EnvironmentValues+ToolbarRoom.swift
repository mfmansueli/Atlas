//
//  EnvironmentValues+ToolbarRoom.swift
//  Atlas
//

import SwiftUI

extension EnvironmentValues {
    /// Where the toolbar's items say how much room they take
    /// (`ToolbarRoomItem`); the workspace keeps it in its toolbar layout.
    /// Nothing listens outside a workspace.
    @Entry var reportToolbarRoom = ToolbarRoomReport()
}

extension View {
    /// Reports this toolbar item's width as `item`'s room, and 0 once it's
    /// gone.
    func reportsToolbarRoom(_ item: ToolbarRoomItem) -> some View {
        modifier(ToolbarRoomReporter(item: item))
    }
}
