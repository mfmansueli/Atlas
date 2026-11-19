//
//  WelcomeChip.swift
//  Atlas
//

import Foundation

/// One chip around the globe in the welcome header: a storefront's
/// language with its flag ("🇩🇪 Deutsch"), or now and then a price in a
/// local currency ("€ 4,99"). Flags pair with App Store Connect's own
/// locales (Portuguese is 🇧🇷 and 🇵🇹), so a flag always means a
/// storefront's language. Decoration: hidden from VoiceOver.
struct WelcomeChip: Hashable, Sendable {
    enum Content: Hashable, Sendable {
        case language(flag: String, name: String)
        case price(currency: String, amount: String)
    }

    var content: Content
    /// Seconds into its slot's 20-second cycle it starts at (the design's
    /// negative `animation-delay`).
    var delay: TimeInterval

    /// A slot shows its four chips and one empty beat every 20 s.
    static let cycle: TimeInterval = 20

    struct Appearance: Hashable, Sendable {
        var opacity: Double
        /// Points: rises in from below, lifts away above.
        var offset: Double
        var scale: Double
    }

    /// In 0.5 s, stays 3 s, out 0.5 s (of the 20), as the design's `wlpop`
    /// keyframes; `pace` 2 is the reading screen's 10 s cycle.
    func appearance(at time: TimeInterval, pace: Double = 1) -> Appearance {
        let cycle = Self.cycle
        var position = (time * pace + delay).truncatingRemainder(dividingBy: cycle) / cycle
        if position < 0 { position += 1 }
        switch position {
        case ..<0.025:
            let progress = position / 0.025
            return Appearance(opacity: progress, offset: 8 * (1 - progress), scale: 0.82 + 0.18 * progress)
        case ..<0.17:
            return Appearance(opacity: 1, offset: 0, scale: 1)
        case ..<0.195:
            let progress = (position - 0.17) / 0.025
            return Appearance(opacity: 1 - progress, offset: -8 * progress, scale: 1 - 0.1 * progress)
        default:
            return Appearance(opacity: 0, offset: -8, scale: 0.9)
        }
    }
}
