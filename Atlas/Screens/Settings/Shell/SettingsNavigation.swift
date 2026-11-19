//
//  SettingsNavigation.swift
//  Atlas
//

import Observation

/// The pane Settings shows. Atlas Help's Show Me sets it before opening
/// Settings, so "Settings → Accounts" lands on Accounts.
@MainActor
@Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()

    var pane: SettingsPane

    init(pane: SettingsPane = .general) {
        self.pane = pane
    }
}
