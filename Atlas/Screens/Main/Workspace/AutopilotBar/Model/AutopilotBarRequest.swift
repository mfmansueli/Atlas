//
//  AutopilotBarRequest.swift
//  Atlas
//

import Foundation

/// A request the person sent from the Autopilot bar with one of its
/// actions (board 80: a click on Suggest Texts is a message): what they
/// clicked, the section it was sent from, and when. It's their bubble in
/// the conversation and the quote under the working strip.
struct AutopilotBarRequest: Identifiable, Hashable, Sendable {
    var id = UUID()
    let appID: StoreApp.ID
    /// “Suggest Texts”.
    let title: String
    /// What it runs, for Try Again.
    var action: WorkspaceAutopilotAction?
    /// Where it was sent from: Show goes back there.
    let section: AppWorkspaceSection
    var sentAt: Date

    /// “Suggest Texts · Store Page · German”: the button, then what the
    /// assistant works on, or the section while nothing does yet.
    func text(subject: String?) -> String {
        "\(title) · \(subject ?? section.title)"
    }
}
