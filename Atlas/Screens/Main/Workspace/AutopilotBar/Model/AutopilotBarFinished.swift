//
//  AutopilotBarFinished.swift
//  Atlas
//

import Foundation

/// A request that ended with something to show (board 80): the strip's
/// “Done · Store Page · German” with Show until the person looks, then a
/// line under Earlier today in the open bar.
struct AutopilotBarFinished: Identifiable, Hashable, Sendable {
    var id = UUID()
    let appID: StoreApp.ID
    /// “Store Page · German”, or the button's request when it came from
    /// the bar: “Suggest Texts · Store Page · German”.
    let what: String
    /// “6 suggestions”, for the Earlier today line.
    var result: String?
    /// What the strip says under it: where to look.
    var text: String
    /// Show opens it.
    let section: AppWorkspaceSection
    var endedAt: Date

    /// The strip's key, so ✕ hides this one only.
    var key: String { "ask.\(id.uuidString)" }

    /// “Done · Store Page · German”.
    var title: String {
        String(localized: "Done · \(what)", comment: "kind:done-state · the Autopilot bar's strip once a request ends")
    }
}
