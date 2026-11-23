//
//  AddKeyCopy.swift
//  Atlas
//

import Foundation

/// The connect form's header while another team's key is added (the
/// canvas's Welcome `addkey` scene).
enum AddKeyCopy {
    static var eyebrow: String {
        String(localized: "Another App Store Connect team", comment: "kind:other")
    }

    /// "Same steps as your first setup, for the other team. Northpier
    /// Studio stays connected; switch teams in the app switcher."
    static func subtitle(keeping team: String) -> String {
        String(
            localized: "Same steps as your first setup, for the other team. \(team) stays connected; switch teams in the app switcher.",
            comment: "kind:description"
        )
    }
}
