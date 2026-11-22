//
//  HeroButtonStyle.swift
//  Atlas
//

import SwiftUI

/// The hero button (README — Design system §4, effect 8): Liquid Glass with
/// a deep blue tint, 38 pt, one per screen. Only Welcome's Get Started and
/// the paywall's buy button. The system swells it under the pointer and
/// squeezes it on click, and handles Reduce Motion itself.
extension View {
    func heroButton() -> some View {
        buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .tint(Palette.heroBlue)
    }
}
