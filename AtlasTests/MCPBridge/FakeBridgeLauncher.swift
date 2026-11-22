//
//  FakeBridgeLauncher.swift
//  AtlasTests
//

import Foundation

/// Answers `openAtlas()` with one outcome and counts the calls.
final class FakeBridgeLauncher: MCPBridgeLauncher, @unchecked Sendable {
    private let lock = NSLock()
    private let outcome: MCPBridgeLaunch
    private var calls = 0

    init(_ outcome: MCPBridgeLaunch) {
        self.outcome = outcome
    }

    func openAtlas() async -> MCPBridgeLaunch {
        lock.withLock { calls += 1 }
        return outcome
    }

    var opened: Int {
        lock.withLock { calls }
    }
}
