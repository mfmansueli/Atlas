//
//  WorkspaceSheet.swift
//  Atlas
//

import Foundation

/// The window-wide sheets a scene can open on.
enum WorkspaceSheet: Hashable, Sendable {
    case review
    /// Review & Push on every app's proposals from one assistant, as the
    /// toolbar indicator's "Review Suggestions…" opens it.
    case proposals(client: String)
    /// Review & Push on its Activity tab (⌘Y).
    case activity
    /// "Set Up Your Assistant".
    case assistantSetup
}
