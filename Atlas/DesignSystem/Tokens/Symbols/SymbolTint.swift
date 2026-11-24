//
//  SymbolTint.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The colour an SF Symbol is drawn in (README — Design system §13, board
/// 72): one of macOS's own system colours, so it follows dark mode,
/// Increase Contrast and the accent by itself. No tile and no gradient
/// behind it. `ai` is the one purple: suggestions, Autopilot and the AI
/// Assistants pane. `design-tokens.json → symbol` names them by these raw
/// values.
enum SymbolTint: String, CaseIterable, Sendable {
    case systemGray
    case systemBlue
    case systemOrange
    case systemTeal
    case systemPink
    case systemBrown
    case systemGreen
    case systemYellow
    case systemIndigo
    case systemRed
    /// What AI brought: `Palette.ai`.
    case ai
    /// Secondary label: the offline mark, menus' symbol column.
    case secondary

    var color: Color {
        switch self {
        case .systemGray: Color(nsColor: .systemGray)
        case .systemBlue: Color(nsColor: .systemBlue)
        case .systemOrange: Color(nsColor: .systemOrange)
        case .systemTeal: Color(nsColor: .systemTeal)
        case .systemPink: Color(nsColor: .systemPink)
        case .systemBrown: Color(nsColor: .systemBrown)
        case .systemGreen: Color(nsColor: .systemGreen)
        case .systemYellow: Color(nsColor: .systemYellow)
        case .systemIndigo: Color(nsColor: .systemIndigo)
        case .systemRed: Color(nsColor: .systemRed)
        case .ai: Palette.ai
        case .secondary: Palette.label2
        }
    }
}
