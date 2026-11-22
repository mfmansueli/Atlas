//
//  CountTickPolicy.swift
//  Atlas
//

import Foundation

/// When a badge's count ticks (effect 4): only going up, because new
/// suggestions came. Going down is still. A new scope (another app) is a new
/// baseline, and the first moments after the badge appears or the scope
/// changes are loading, not news: nothing animates on page load or when
/// switching.
struct CountTickPolicy: Equatable {
    /// Counts settle this long after the badge appears or its app changes.
    static let settleDelay: TimeInterval = 2

    private(set) var count: Int
    private(set) var scope: String?
    /// When the badge appeared or its scope last changed.
    private(set) var since: Date

    init(count: Int, scope: String? = nil, now: Date = .now) {
        self.count = count
        self.scope = scope
        since = now
    }

    /// Whether going to `count` in `scope` at `now` would tick.
    func wouldTick(count newCount: Int, scope newScope: String?, now: Date = .now) -> Bool {
        newScope == scope && newCount > count && now.timeIntervalSince(since) >= Self.settleDelay
    }

    /// Takes the new count: true when it ticks.
    mutating func update(count newCount: Int, scope newScope: String?, now: Date = .now) -> Bool {
        let ticks = wouldTick(count: newCount, scope: newScope, now: now)
        if newScope != scope {
            scope = newScope
            since = now
        }
        count = newCount
        return ticks
    }
}
