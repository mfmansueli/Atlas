//
//  ArrivalLedger.swift
//  Atlas
//

import Foundation

/// Which suggestions and images get the arrival (effect 3, Arrived): only
/// one that lands while the person looks, once. A card shown more than a
/// moment after its suggestion arrived was already there (the page opened,
/// the section or language switched), so it stays still: motion means
/// something just happened. Each arrival plays once a launch, so a card
/// scrolled out and back, or redrawn, doesn't play it again.
///
/// Arrivals that land together are a burst: each claim gets its place in
/// it, so a list arrives 70 ms apart and only its first six move
/// (`MotionTiming.staggerDelay(for:)`).
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
    /// Claims this close to a burst's first one belong to it.
    static let burstWindow: TimeInterval = 0.5

    private var played: Set<String> = []
    private var burstStart: Date?
    private var burstCount = 0

    /// Whether `key`, arrived at `arrivedAt`, would get its arrival now.
    /// Nil (built-in checks, loaded files with no date) never does.
    func isFresh(key: String, arrivedAt: Date?, window: TimeInterval = ArrivalLedger.suggestionWindow, now: Date = .now) -> Bool {
        guard let arrivedAt, !played.contains(key) else { return false }
        let age = now.timeIntervalSince(arrivedAt)
        return age >= -Self.clockSlack && age <= window
    }

    /// Takes `key`'s arrival: its place in the current burst (0 for the
    /// first), once, when it's fresh; nil otherwise.
    func claim(key: String, arrivedAt: Date?, window: TimeInterval = ArrivalLedger.suggestionWindow, now: Date = .now) -> Int? {
        guard isFresh(key: key, arrivedAt: arrivedAt, window: window, now: now) else { return nil }
        played.insert(key)
        if let burstStart, now.timeIntervalSince(burstStart) <= Self.burstWindow {
            burstCount += 1
        } else {
            burstStart = now
            burstCount = 0
        }
        return burstCount
    }
}
