//
//  EventArtworkViewerStyle.swift
//  Atlas
//

import SwiftUI

/// The full-size viewer's own colors (board 47): black in light and dark
/// alike (the viewer forces the dark appearance, so `Palette` resolves dark), white text, hairlines that turn solid with Increase Contrast.
enum EventArtworkViewerStyle {
    static let background = Palette.viewerStage
    static let panel = Palette.viewerPanel
    static let selected = Color.white.opacity(0.92)
    static let selectedText = Color.black
    static let use = Palette.accent
    static let useHover = Palette.accent.opacity(0.85)
    static let inUse = Palette.ok

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
