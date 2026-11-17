//
//  DebugAnalyticsRandom.swift
//  Atlas
//

#if DEBUG
import Foundation

/// A small seeded generator, so a scene's numbers are the same every launch.
struct DebugAnalyticsRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// 0..<1.
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }

    /// `expected` as a whole number: its floor, plus one as often as its
    /// fraction says.
    mutating func count(_ expected: Double) -> Int {
        let whole = expected.rounded(.down)
        return Int(whole) + (next() < expected - whole ? 1 : 0)
    }
}
#endif
