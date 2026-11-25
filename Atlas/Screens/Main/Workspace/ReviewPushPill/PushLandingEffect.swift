//
//  PushLandingEffect.swift
//  Atlas
//

import SwiftUI

/// What Review & Push does when an accepted change lands on it (board 80):
/// it swells to 1.1 and back on a 0.5 s spring (`MotionTiming.sentLand`)
/// while a blue ring opens 14 pt around it and fades (0.7 s,
/// `MotionTiming.sentRing`). Once per landing, on `landings` going up.
/// With Reduce Motion nothing moves: the count just changes.
struct PushLandingEffect: ViewModifier {
    /// How far it swells…
    static let scale: CGFloat = 1.1
    /// …and how far the ring opens, from this opacity to none.
    static let ringSpread: CGFloat = 14
    static let ringOpacity = 0.6
    /// The swell's share of the spring: the way up.
    static let swellUp: TimeInterval = 0.15

    let landings: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let trigger = reduceMotion ? 0 : landings
        let spring = MotionTiming.sentLand.spring ?? Spring()
        content
            .background { ring(trigger: trigger) }
            .keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(Self.scale, duration: Self.swellUp, spring: spring)
                SpringKeyframe(1, duration: MotionTiming.sentLand.duration - Self.swellUp, spring: spring)
            }
    }

    /// Outside the capsule, so none of it shows through the glass.
    private func ring(trigger: Int) -> some View {
        Color.clear
            .keyframeAnimator(initialValue: Ring(), trigger: trigger) { view, ring in
                view.overlay {
                    Capsule()
                        .strokeBorder(Palette.accent.opacity(ring.opacity), lineWidth: max(ring.spread, 0.01))
                        .padding(-ring.spread)
                }
            } keyframes: { _ in
                KeyframeTrack(\.spread) {
                    LinearKeyframe(0, duration: 0)
                    LinearKeyframe(Self.ringSpread, duration: MotionTiming.sentRing.duration, timingCurve: .easeOut)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(Self.ringOpacity, duration: 0)
                    LinearKeyframe(0, duration: MotionTiming.sentRing.duration, timingCurve: .easeOut)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The ring at one moment; still and invisible at rest.
    private struct Ring {
        var spread: CGFloat = 0
        var opacity: Double = 0
    }
}
