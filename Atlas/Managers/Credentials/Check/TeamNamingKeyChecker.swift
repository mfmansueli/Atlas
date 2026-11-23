//
//  TeamNamingKeyChecker.swift
//  Atlas
//

import Foundation

/// "Add Another Key…"'s check: the usual one, then the team's name, so the
/// sheet can say which team it added ("Fieldworks Studio is connected").
/// A name that can't be read leaves it nil; the key still works.
struct TeamNamingKeyChecker: KeyChecker {
    let base: any KeyChecker
    let lookup: any TeamNameLookup

    func check(_ credentials: AppStoreConnectCredentials) async throws -> KeyAccessCheck {
        var check = try await base.check(credentials)
        if check.teamName == nil {
            check.teamName = await lookup.teamName(for: credentials)
        }
        return check
    }
}
