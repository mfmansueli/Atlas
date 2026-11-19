//
//  EventArtworkViewerStyle.swift
//  Atlas
//

import SwiftUI

/// The full-size viewer's own colors (board 47): black in light and dark
/// alike, white text, hairlines that turn solid with Increase Contrast.
enum EventArtworkViewerStyle {
    static let background = Color(red: 11 / 255, green: 11 / 255, blue: 15 / 255)
    static let panel = Color(red: 32 / 255, green: 32 / 255, blue: 38 / 255).opacity(0.92)
    static let selected = Color.white.opacity(0.92)
    static let selectedText = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let use = Color(red: 10 / 255, green: 132 / 255, blue: 1)
    static let useHover = Color(red: 43 / 255, green: 149 / 255, blue: 1)
    static let inUse = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)

    static func hairline(_ contrast: ColorSchemeContrast) -> Color {
        .white.opacity(contrast == .increased ? 0.6 : 0.12)
    }

    static func secondary(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? .white : .white.opacity(0.62)
    }

    static func control(_ isHovered: Bool) -> Color {
        .white.opacity(isHovered ? 0.22 : 0.12)
    }
}
