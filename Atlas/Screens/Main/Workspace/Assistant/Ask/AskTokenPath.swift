//
//  AskTokenPath.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// The token's way from the asking button to the toolbar's Assistant
/// button: an arc that rises quickly and crosses slowly at first, then
/// speeds into the target, shrinking to half and fading as it lands
/// (board 56: horizontal cubic-bezier(.5, 0, .9, .6), vertical
/// cubic-bezier(.1, .7, .3, 1), both 0.68 s; the fade the last 0.16 s).
struct AskTokenPath: Equatable {
    let from: CGPoint
    let to: CGPoint

    /// After the click, before the token moves.
    static let delay: TimeInterval = 0.04
    static let duration: TimeInterval = 0.68
    static let fadeStart: TimeInterval = 0.54
    static let fadeDuration: TimeInterval = 0.16
    /// When the token is gone and the toolbar starts working, after the
    /// click.
    static let landing: TimeInterval = 0.76
    /// The ring around the Assistant button after the landing.
    static let ringDuration: TimeInterval = 0.9
    /// How far the ring grows out of the button.
    static let ringSpread: CGFloat = 14
    /// The token's size, in points.
    static let size: CGFloat = 26

    static let horizontal = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.5, y: 0), endControlPoint: UnitPoint(x: 0.9, y: 0.6))
    static let vertical = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.1, y: 0.7), endControlPoint: UnitPoint(x: 0.3, y: 1))

    struct State: Equatable {
        var center: CGPoint
        var scale: CGFloat
        var opacity: Double
    }

    /// Where the token is `elapsed` seconds into its flight (after
    /// `delay`).
    func state(at elapsed: TimeInterval) -> State {
        let progress = min(1, max(0, elapsed / Self.duration))
        let across = Self.horizontal.value(at: progress)
        let up = Self.vertical.value(at: progress)
        let center = CGPoint(x: from.x + (to.x - from.x) * across, y: from.y + (to.y - from.y) * up)
        let opacity = elapsed < Self.fadeStart ? 1 : max(0, 1 - (elapsed - Self.fadeStart) / Self.fadeDuration)
        return State(center: center, scale: 1 - 0.5 * up, opacity: opacity)
    }

    /// The ring `elapsed` seconds after the landing: how far it has grown
    /// out of the button, and how strong it still is. Nil once it's gone.
    static func ring(at elapsed: TimeInterval) -> (spread: CGFloat, opacity: Double)? {
        guard elapsed >= 0, elapsed < ringDuration else { return nil }
        let eased = UnitCurve.easeOut.value(at: elapsed / ringDuration)
        return (ringSpread * eased, 0.6 * (1 - eased))
    }
}
