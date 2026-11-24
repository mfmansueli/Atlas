//
//  NominationType.swift
//  Atlas
//

import Foundation

/// What a nomination tells Apple's editors about (`type`): a new app, new
/// features in an existing one, or new content such as an event.
enum NominationType: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case appLaunch = "APP_LAUNCH"
    case appEnhancements = "APP_ENHANCEMENTS"
    case newContent = "NEW_CONTENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appLaunch: String(localized: "App Launch", comment: "kind:field-label")
        case .appEnhancements: String(localized: "App Enhancements", comment: "kind:field-label")
        case .newContent: String(localized: "New Content", comment: "kind:field-label")
        }
    }

    /// The option's one line under its title.
    var line: String {
        switch self {
        case .appLaunch: String(localized: "A new app", comment: "kind:description")
        case .appEnhancements: String(localized: "New features in an existing app", comment: "kind:description")
        case .newContent: String(localized: "New content, like an event or season", comment: "kind:description")
        }
    }

    var systemImage: String {
        switch self {
        case .appLaunch: "paperplane"
        case .appEnhancements: "arrow.up.circle"
        case .newContent: "calendar"
        }
    }
}
