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

    /// The step while App Store Connect checks the new key.
    static var checkingTitle: String {
        String(localized: "Checking the new key…", comment: "kind:loading")
    }

    /// "Atlas is asking App Store Connect which team and apps this key
    /// opens. Northpier Studio stays as it is."
    static func checkingMessage(keeping team: String) -> String {
        String(
            localized: "Atlas is asking App Store Connect which team and apps this key opens. \(team) stays as it is.",
            comment: "kind:loading"
        )
    }

    /// VoiceOver's name for the bar.
    static var checkingProgress: String {
        String(localized: "Checking the key", comment: "kind:label")
    }
}
