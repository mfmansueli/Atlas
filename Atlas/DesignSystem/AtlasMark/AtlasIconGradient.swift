//
//  AtlasIconGradient.swift
//  Atlas
//

import SwiftUI

/// The app icon's background, top to bottom, as `Atlas.icon` fills it:
/// bright blue in light appearance, a deeper blue in dark. For the places
/// that draw the icon themselves.
enum AtlasIconGradient {
    /// #1FC2FF → #0A5CF2.
    static let light = [
        Color(red: 0x1F / 255, green: 0xC2 / 255, blue: 0xFF / 255),
        Color(red: 0x0A / 255, green: 0x5C / 255, blue: 0xF2 / 255),
    ]

    /// #1590E8 → #0A3FB8.
    static let dark = [
        Color(red: 0x15 / 255, green: 0x90 / 255, blue: 0xE8 / 255),
        Color(red: 0x0A / 255, green: 0x3F / 255, blue: 0xB8 / 255),
    ]

    static func colors(for colorScheme: ColorScheme) -> [Color] {
        colorScheme == .dark ? dark : light
    }
}
