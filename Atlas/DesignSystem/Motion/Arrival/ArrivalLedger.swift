//
//  ArrivalLedger.swift
//  Atlas
//

import Foundation

/// Which suggestions and images get the arrival (effect 2): only one that
/// lands while the person looks, once. A card shown more than a moment after
/// its suggestion arrived was already there (the page opened, the section or
/// language switched), so it stays still: motion means something just
/// happened. Each arrival plays once a launch, so a card scrolled out and
/// back, or redrawn, doesn't play it again.
@MainActor
final class ArrivalLedger {
    static let shared = ArrivalLedger()

    /// A suggestion lands on the page within a moment of arriving.
    static let suggestionWindow: TimeInterval = 2
    /// An image is read or rendered after its file is made, so it gets
    /// longer.
    static let imageWindow: TimeInterval = 8
    /// Clocks of the assistant's machine and this Mac can disagree a little.
    static let clockSlack: TimeInterval = 1

    private var played: Set<String> = []

    /// Whether `key`, arrived at `arrivedAt`, would get its arrival now.
    /// Nil (built-in checks, loaded files with no date) never does.
    func isFresh(key: String, arrivedAt: Date?, window: TimeInterval = ArrivalLedger.suggestionWindow, now: Date = .now) -> Bool {
        guard let arrivedAt, !played.contains(key) else { return false }
        let age = now.timeIntervalSince(arrivedAt)
        return age >= -Self.clockSlack && age <= window
    }

    /// Takes `key`'s arrival: true once, when it's fresh.
    func claim(key: String, arrivedAt: Date?, window: TimeInterval = ArrivalLedger.suggestionWindow, now: Date = .now) -> Bool {
        guard isFresh(key: key, arrivedAt: arrivedAt, window: window, now: now) else { return false }
        played.insert(key)
        return true
    }
}
