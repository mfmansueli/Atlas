//
//  ToolbarRoomItem.swift
//  Atlas
//

import Foundation

/// What takes room in the workspace toolbar beyond its fixed part
/// (`WorkspaceToolbarLayout.fixedRoom`): the title and the section menu
/// that lead it, the label Review & Push adds to its icon,
/// and the items only some sections or plans have. Each reports its width,
/// so the title truncates and the labels fold only when they don't fit.
enum ToolbarRoomItem: Hashable, CaseIterable, Sendable {
    /// The section's title and status, as wide as they want.
    case title
    /// The section menu, while the sidebar is hidden.
    case sectionMenu
    /// Review & Push's label, beyond its icon and count.
    case reviewLabel
    /// Pro, while the person is on Free.
    case proButton

    /// An item of its own, with a gap beside it; a label grows its button.
    var isItem: Bool {
        switch self {
        case .proButton: true
        case .title, .sectionMenu, .reviewLabel: false
        }
    }

    /// A label that folds to its button's icon.
    var isLabel: Bool {
        switch self {
        case .reviewLabel: true
        case .title, .sectionMenu, .proButton: false
        }
    }

    /// What leads the toolbar, which the layout counts on its own.
    var isLead: Bool {
        switch self {
        case .title, .sectionMenu: true
        case .reviewLabel, .proButton: false
        }
    }
}
