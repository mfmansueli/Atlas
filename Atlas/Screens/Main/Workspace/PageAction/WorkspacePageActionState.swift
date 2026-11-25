//
//  WorkspacePageActionState.swift
//  Atlas
//

import Foundation

/// How the toolbar shows a section's page action, as the section reports it
/// (`reportsPageAction(_:for:)`): on, off with why, or gone while one of
/// its items is open (a custom product page's editor has its own actions).
enum WorkspacePageActionState: Equatable, Sendable {
    case enabled
    /// Shown but can't run: still reading, Apple's limit, a key that can't
    /// write. The reason, when there is one, is the tooltip.
    case disabled(reason: String?)
    case hidden

    var isShown: Bool { self != .hidden }

    var isEnabled: Bool { self == .enabled }

    /// The tooltip while it's off, when the section said why.
    var reason: String? {
        if case let .disabled(reason) = self { return reason }
        return nil
    }
}
