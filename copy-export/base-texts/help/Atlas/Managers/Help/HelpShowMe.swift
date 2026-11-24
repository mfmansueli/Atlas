//
//  HelpShowMe.swift
//  Atlas
//

import Foundation

/// Where an article's Show Me button opens Atlas: a Settings pane, a
/// section of the app selected in the main window, or Review & Push.
enum HelpShowMe: Hashable, Sendable {
    case settings(SettingsPane)
    case section(AppWorkspaceSection)
    case reviewPush

    /// `settings:accounts`, `section:storePage`, `reviewPush`.
    init?(_ text: String) {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        switch parts.first {
        case "settings": guard let pane = parts.last.flatMap(SettingsPane.init(rawValue:)) else { return nil }
            self = .settings(pane)
        case "section": guard let section = parts.last.flatMap(AppWorkspaceSection.init(rawValue:)) else { return nil }
            self = .section(section)
        case "reviewPush": self = .reviewPush
        default: return nil
        }
    }

    /// "Settings → Accounts", "Store Page", "Review & Push".
    var title: String {
        switch self {
        case let .settings(pane): String(localized: "Settings → \(pane.title)")
        case let .section(section): section.fullTitle
        case .reviewPush: String(localized: "Review & Push")
        }
    }
}
