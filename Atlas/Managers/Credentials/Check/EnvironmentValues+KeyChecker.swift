//
//  EnvironmentValues+KeyChecker.swift
//  Atlas
//

import SwiftUI

extension EnvironmentValues {
    /// How Connect and Settings → Account check keys: Apple by default,
    /// canned answers in DEBUG scenes.
    @Entry var keyChecker: any KeyChecker = LiveKeyChecker()
    /// How "Add Another Key…" reads the new key's team name: App Store
    /// Connect's certificates by default, a canned name in DEBUG scenes.
    @Entry var teamNameLookup: any TeamNameLookup = LiveTeamNameLookup()
}
