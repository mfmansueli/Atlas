//
//  AIArrivedImage.swift
//  Atlas
//

import SwiftUI

/// Effect 3 · Arrived, the image version (README — Design system §7, v2):
/// a new image the assistant made (event artwork, Autopilot's captures)
/// develops like a photo, 0.8 s on the standard curve, from a 9 pt blur,
/// low saturation, 40 % opacity and 97 % scale. With Reduce Motion it fades
/// in over 0.2 s. Only a fresh image plays (`ArrivalLedger`, the image
/// window), several at once 70 ms apart.
struct AIArrivedImage: ViewModifier {
    let key: String
    let arrivedAt: Date?
    var ledger: ArrivalLedger = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var developed: Double

    /// How long the image takes to develop.
    static let duration: TimeInterval = 0.8

    init(key: String, arrivedAt: Date?, ledger: ArrivalLedger = .shared) {
        self.key = key
        self.arrivedAt = arrivedAt
        self.ledger = ledger
        _developed = State(initialValue: ledger.isFresh(key: key, arrivedAt: arrivedAt, window: ArrivalLedger.imageWindow) ? 0 : 1)
    }

    func body(content: Content) -> some View {
        let look = Self.look(developed: developed, reduceMotion: reduceMotion)
        content
            .blur(radius: look.blur)
            .saturation(look.saturation)
            .scaleEffect(look.scale)
            .opacity(look.opacity)
            .onAppear(perform: develop)
    }

    private func develop() {
        guard developed < 1 else { return }
        guard let place = ledger.claim(key: key, arrivedAt: arrivedAt, window: ArrivalLedger.imageWindow),
              let delay = MotionTiming.staggerDelay(for: place)
        else {
            developed = 1
            return
        }
        let animation = reduceMotion
            ? AIArrived.reducedFade
            : Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: Self.duration).delay(delay)
        withAnimation(animation) { developed = 1 }
    }

    struct Look: Equatable {
        var blur: CGFloat
        var saturation: Double
        var scale: CGFloat
        var opacity: Double
    }

    /// The image `developed` of the way (0–1); Reduce Motion only fades.
    nonisolated static func look(developed: Double, reduceMotion: Bool) -> Look {
        let rest = 1 - min(max(developed, 0), 1)
        guard !reduceMotion else { return Look(blur: 0, saturation: 1, scale: 1, opacity: 1 - rest) }
        return Look(blur: 9 * rest, saturation: 1 - 0.8 * rest, scale: 1 - 0.03 * rest, opacity: 1 - 0.6 * rest)
    }
}

extension View {
    /// Effect 3 · Arrived on a new image; see `AIArrivedImage`.
    func aiArrivedImage(key: String, arrivedAt: Date?) -> some View {
        modifier(AIArrivedImage(key: key, arrivedAt: arrivedAt))
    }
}
