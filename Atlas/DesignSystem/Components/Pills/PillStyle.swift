//
//  PillStyle.swift
//  Atlas
//

import SwiftUI

/// What a `Pill` means, which picks its colors. Only meaning gets color:
/// confidence, provenance and assistant tags stay neutral.
enum PillStyle: Sendable {
    /// Grey fill: counts, "Base", "All succeeded".
    case neutral
    /// No fill, a hairline edge: "Missing", tier chips, provenance fallbacks.
    case outline
    case increase
    case decrease
    case danger
    case warning
    case machineTranslated
    /// Accent tint: "Edited", "Changes with your next push".
    case accent
    /// Green: a state that's fine, e.g. "Sounds native".
    case ok

    var foreground: Color {
        switch self {
        case .neutral, .outline: Palette.label2
        case .increase: Palette.increase
        case .decrease: Palette.decrease
        case .danger: Palette.err
        case .warning: Palette.warn
        case .machineTranslated: Palette.ai
        case .accent: Palette.accentText
        case .ok: Palette.ok
        }
    }

    var background: Color {
        switch self {
        case .neutral: Palette.fill2
        case .outline: .clear
        case .increase: Palette.increaseTint
        case .decrease: Palette.decreaseTint
        case .danger: Palette.errTint
        case .warning: Palette.warnTint
        case .machineTranslated: Palette.aiSurface
        case .accent: Palette.accentTint
        case .ok: Palette.okTint
        }
    }

    /// Outline pills always draw an edge; the rest only under Increase
    /// Contrast, in their own color.
    func border(increasedContrast: Bool) -> Color? {
        if self == .outline { return Palette.separator2 }
        return increasedContrast ? foreground : nil
    }
}
