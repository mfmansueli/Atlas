//
//  PaywallStyle.swift
//  Atlas
//

import SwiftUI

/// Pro's colours: the brand's blue (README — Design system §1, "Atlas Pro is
/// Atlas; purple stays AI"), on the paywall's left side, the PRO chip and the
/// toolbar's Pro button. Where white text sits on it, the icon's deeper
/// stops (#1590E8 → #0A3FB8) keep it readable; the bright #1FC2FF → #0A5CF2
/// is for fills without text.
enum PaywallStyle {
    /// #0A5CF2, the brand gradient's lower colour.
    static let brandBlue = Palette.brandBottom

    /// Behind white text: the chip.
    static let gradient = LinearGradient(colors: AtlasIconGradient.dark, startPoint: .topLeading, endPoint: .bottomTrailing)

    /// The paywall's left pane, white text on it.
    static let paneGradient = LinearGradient(colors: AtlasIconGradient.dark, startPoint: .top, endPoint: .bottom)

    /// A fill without text on it (the Settings tile).
    static let brightGradient = LinearGradient(colors: AtlasIconGradient.light, startPoint: .top, endPoint: .bottom)

    static let sheetSize = CGSize(width: 840, height: 600)
    static let paneWidth: CGFloat = 320
}
