//
//  PriceChange+Pill.swift
//  Atlas
//

import SwiftUI

/// The change pill's colours (design-tokens.json → `pricing.pillChange`):
/// an increase is amber, since it can cost subscribers; a decrease stays
/// neutral grey. The arrow is `pillSystemImage`.
extension PriceChange {
    var pillTint: Color {
        direction == .increase ? Palette.warn : Palette.label2
    }

    var pillBackground: Color {
        direction == .increase ? Palette.warnTint : Palette.fill2
    }
}
