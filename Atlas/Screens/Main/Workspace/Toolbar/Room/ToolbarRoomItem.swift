//
//  ToolbarRoomItem.swift
//  Atlas
//

import Foundation

/// What takes room in the workspace toolbar beyond its fixed part
/// (`WorkspaceToolbarLayout.fixedRoom`): the labels Autopilot and Review &
/// Push add to their icons, and the items only some sections or plans have.
/// Each reports its width, so the labels fold only when they don't fit.
enum ToolbarRoomItem: Hashable, CaseIterable, Sendable {
    /// Autopilot's label, beyond its icon.
    case autopilotLabel
    /// Review & Push's label, beyond its icon and count.
    case reviewLabel
    /// The language picker the text sections put beside the title.
    case languagePicker
    /// Pro, while the person is on Free.
    case proButton

    /// An item of its own, with a gap beside it; a label grows its button.
    var isItem: Bool {
        switch self {
        case .autopilotLabel, .reviewLabel: false
        case .languagePicker, .proButton: true
        }
    }
}
