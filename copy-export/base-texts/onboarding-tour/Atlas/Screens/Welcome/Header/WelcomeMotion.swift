//
//  WelcomeMotion.swift
//  Atlas
//

import Foundation

/// Where everything in the welcome header is `time` seconds in, from the
/// design's README (board 45): two groups of three tiles ride the band
/// round the globe (one lap in 16 s), the meridian swings 9.6 s each way,
/// the star glints when a group reaches the band's end beside it (every
/// 8 s), the thin orbit leans now and then (7.5 s out of every 17), and
/// the whole mark floats 11 points. `pace` 2 is "Reading your apps…":
/// tiles, meridian, star and chips at double speed. All in the icon's
/// 1024-unit square, centred, y down.
struct WelcomeMotion: Hashable, Sendable {
    var time: TimeInterval
    var pace: Double = 1

    struct Tile: Hashable, Sendable {
        /// Along the band, before the band's −24° turn.
        var x: Double
        var y: Double
        /// −1…1: the tile faces you at ±1 and is a sliver at either end.
        var widthScale: Double
        /// In front of the globe (the band's lower half).
        var isFront: Bool
    }

    struct Star: Hashable, Sendable {
        var scale: Double
        var rotation: Double
        var opacity: Double
        var haloScale: Double
        var haloOpacity: Double
    }

    struct Orbit: Hashable, Sendable {
        /// Degrees, on top of its own 38°.
        var lean: Double
        var openness: Double
    }

    static let lap: TimeInterval = 16
    /// Each tile's head start, seconds into a lap: two groups of three,
    /// 1.2 s apart within a group, half a lap between groups.
    static let tileDelays: [TimeInterval] = [0.96, 2.16, 3.36, 8.96, 10.16, 11.36]
    static let meridianSwing: TimeInterval = 9.6
    static let starCycle: TimeInterval = 8
    static let starDelay: TimeInterval = 4.56
    static let orbitCycle: TimeInterval = 17
    /// The orbit's lean takes this long of each cycle; it rests the rest.
    static let orbitMove: TimeInterval = 7.5
    static let orbitDelay: TimeInterval = 11
    static let floatSwing: TimeInterval = 7

    var tiles: [Tile] {
        Self.tileDelays.map { delay in
            let phase = 2 * Double.pi * (time * pace + delay) / Self.lap
            return Tile(x: -440 * cos(phase), y: 130 * sin(phase), widthScale: sin(phase), isFront: sin(phase) >= 0)
        }
    }

    /// The two meridian ellipses' horizontal scale, 1 → −1 and back.
    var meridianScales: (Double, Double) {
        let swing = Self.meridianSwing
        return (cos(.pi * time * pace / swing), cos(.pi * (time * pace + swing / 2) / swing))
    }

    var star: Star {
        let cycle = Self.starCycle
        var position = (time * pace + Self.starDelay).truncatingRemainder(dividingBy: cycle) / cycle
        if position < 0 { position += 1 }
        let ease = Self.starEase
        if position < 0.3 {
            let progress = ease.value(at: position / 0.3)
            return Star(
                scale: 1 + 0.32 * progress, rotation: 16 * progress, opacity: 0.86 + 0.14 * progress,
                haloScale: 0.45 + 0.55 * progress, haloOpacity: 0.9 * progress
            )
        }
        if position < 0.66 {
            let progress = ease.value(at: (position - 0.3) / 0.36)
            return Star(
                scale: 1.32 - 0.32 * progress, rotation: 16 - 16 * progress, opacity: 1 - 0.14 * progress,
                haloScale: 1 + 0.3 * progress, haloOpacity: 0.9 - 0.9 * progress
            )
        }
        return Star(scale: 1, rotation: 0, opacity: 0.86, haloScale: 1.3, haloOpacity: 0)
    }

    /// About 3° one way, back through centre to 3° the other, and settled,
    /// opening by a tenth while it moves: one motion that starts and ends
    /// at rest. Its 17 s is out of step with the tiles and the star on
    /// purpose, so it isn't paced.
    var orbit: Orbit {
        var position = (time + Self.orbitDelay).truncatingRemainder(dividingBy: Self.orbitCycle)
        if position < 0 { position += Self.orbitCycle }
        guard position < Self.orbitMove else { return Orbit(lean: 0, openness: 1) }
        let unit = position / Self.orbitMove
        let rest = pow(sin(.pi * unit), 2)
        return Orbit(lean: 4.2 * sin(2 * .pi * unit) * rest, openness: 1 + 0.11 * rest)
    }

    /// Points up (−5) to down (+6), 7 s each way.
    var floatOffset: Double {
        -5 + 11 * (1 - cos(.pi * time / Self.floatSwing)) / 2
    }

    /// The star's CSS `cubic-bezier(.45, 0, .25, 1)`.
    private static let starEase = UnitBezier(x1: 0.45, y1: 0, x2: 0.25, y2: 1)
}
