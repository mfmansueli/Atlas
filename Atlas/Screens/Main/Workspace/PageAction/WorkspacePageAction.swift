//
//  WorkspacePageAction.swift
//  Atlas
//

import Foundation

/// A section's one create action, in the window's toolbar where the
/// Autopilot button was (board 80): New Page…, New Event…, New
/// Nomination…, Add Subscription…, Add Screenshots…. Each opens a sheet (or
/// a draft) of its section, so its title ends with “…”. The page itself no
/// longer has the button; its empty state names it (board 74).
/// `AppWorkspaceSection.pageAction` is the one source.
struct WorkspacePageAction: Equatable, Sendable {
    /// The section it creates in.
    let section: AppWorkspaceSection
    /// “New Page…”.
    let title: String
    /// The SF Symbol beside the title.
    let systemImage: String
    /// What it makes, for the tooltip.
    let help: String
    /// The button's accessibility identifier, the one the page's own
    /// button had, so UI tests find it in the toolbar.
    let identifier: String
}
