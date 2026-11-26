//
//  PageCardTone.swift
//  Atlas
//

import SwiftUI

/// What a page card's status line means, which picks its colour (README-DS
/// §1): purple is what the assistant brought, amber and green are state,
/// grey is neutral.
enum PageCardTone: Hashable, Sendable {
    /// "3 suggested": suggestions from the assistant wait.
    case ai
    /// "2 need you", "Fewer page views · crashes up".
    case warning
    /// "Ready".
    case ok
    /// Facts without a verdict: "1,284 subscribers".
    case neutral

    var color: Color {
        switch self {
        case .ai: Palette.ai
        case .warning: Palette.warn
        case .ok: Palette.ok
        case .neutral: Palette.label2
        }
    }
}
