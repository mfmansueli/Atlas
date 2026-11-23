//
//  TeamNameLookup.swift
//  Atlas
//

import Foundation

/// Reads the team a key belongs to, for "Add Another Key…": App Store
/// Connect's certificates (`LiveTeamNameLookup`), or a canned name in DEBUG
/// scenes and tests. Nil when the name can't be read.
protocol TeamNameLookup: Sendable {
    func teamName(for credentials: AppStoreConnectCredentials) async -> String?
}
