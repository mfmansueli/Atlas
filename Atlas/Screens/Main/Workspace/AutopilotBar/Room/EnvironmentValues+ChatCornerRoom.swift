//
//  EnvironmentValues+ChatCornerRoom.swift
//  Atlas
//

import SwiftUI

extension EnvironmentValues {
    /// The room a page leaves at its bottom edge for the closed Autopilot
    /// bar (`AutopilotBarRoom.room(closedHeight:)` in an app's workspace),
    /// so its last content or a bar there isn't covered by it. Pages take
    /// it with `leavesChatRoom(_:)`; a section's toast sits above it. 0
    /// where there's no bar: sheets, previews and DEBUG hosts.
    @Entry var chatCornerRoom: CGFloat = 0
}
