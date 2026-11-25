//
//  WorkspaceAutopilotDetail.swift
//  Atlas
//

import Foundation

/// The detail page open inside a section, or the section's empty state,
/// which the toolbar's Autopilot button follows (README-Toolbar: “inside a detail page the button's label
/// follows what's open, and the menu keeps the section's other actions”).
/// The section sets it on `WorkspaceNavigator.autopilotDetail` while the
/// page shows.
enum WorkspaceAutopilotDetail: Hashable, Sendable {
    /// One In-App Event's page: Make the Artwork….
    case event
    /// One custom product page in the editor: Make Screenshots for This Page….
    case productPage
    /// In-App Events with no event yet (board 74 · 3): Suggest an Event…,
    /// not Make Event Artwork….
    case noEvents

    /// The section it belongs to; elsewhere it doesn't count.
    var section: AppWorkspaceSection {
        switch self {
        case .event, .noEvents: .inAppEvents
        case .productPage: .productPages
        }
    }
}
