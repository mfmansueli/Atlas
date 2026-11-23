//
//  LiveTeamNameLookup.swift
//  Atlas
//

import Foundation

/// The team's name from its certificates, as the main window reads it. No
/// certificates, a role that can't read them, or the network: nil.
struct LiveTeamNameLookup: TeamNameLookup {
    func teamName(for credentials: AppStoreConnectCredentials) async -> String? {
        try? await AppStoreConnectClient(credentials: credentials).teamName()
    }
}
