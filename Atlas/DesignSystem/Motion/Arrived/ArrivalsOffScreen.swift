//
//  ArrivalsOffScreen.swift
//  Atlas
//

import Observation

/// Fresh arrivals that landed outside the visible part of their page
/// (effect 3, Arrived): instead of animating what nobody sees, they appear
/// still and the window says “3 new below” (`NewArrivalsBelowNotice`)
/// until they're scrolled to or leave the page.
@MainActor
@Observable
final class ArrivalsOffScreen {
    static let shared = ArrivalsOffScreen()

    private(set) var keys: Set<String> = []

    var count: Int { keys.count }

    /// `key` arrived out of sight.
    func add(_ key: String) {
        keys.insert(key)
    }

    /// `key` was scrolled to, or left the page.
    func remove(_ key: String) {
        guard keys.contains(key) else { return }
        keys.remove(key)
    }

    /// The person read the notice, or went elsewhere.
    func removeAll() {
        guard !keys.isEmpty else { return }
        keys.removeAll()
    }
}
