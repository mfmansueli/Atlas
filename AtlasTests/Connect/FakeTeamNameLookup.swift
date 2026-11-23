//
//  FakeTeamNameLookup.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Answers every key with `name` and counts the asks.
struct FakeTeamNameLookup: TeamNameLookup {
    let name: String?
    let asked = Counter()

    func teamName(for _: AppStoreConnectCredentials) async -> String? {
        await asked.add()
        return name
    }

    actor Counter {
        private(set) var count = 0
        func add() { count += 1 }
    }
}
