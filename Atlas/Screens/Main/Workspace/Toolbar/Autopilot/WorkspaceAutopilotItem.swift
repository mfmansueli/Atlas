//
//  WorkspaceAutopilotItem.swift
//  Atlas
//

import Foundation

/// One thing the Autopilot button can do in a section, named as a verb for
/// what it makes there: “Make Screenshots…”, “Suggest Texts…”, “Draft
/// Replies…”. The first of a section's items is the button's own action.
struct WorkspaceAutopilotItem: Identifiable, Equatable {
    let action: WorkspaceAutopilotAction
    let title: String
    var systemImage = "sparkles"
    /// Free plan: the item shows PRO and opens the paywall.
    var isPro = false
    var isEnabled = true

    var id: WorkspaceAutopilotAction { action }
}
