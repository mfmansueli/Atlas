//
//  DebugTeamNameLookup.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG scenes name every added key's team the same way, never asking
/// Apple: `ConnectDebugScenes.addedTeamName`.
struct DebugTeamNameLookup: TeamNameLookup {
    func teamName(for _: AppStoreConnectCredentials) async -> String? {
        ConnectDebugScenes.addedTeamName
    }
}
#endif
