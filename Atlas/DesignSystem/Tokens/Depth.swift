//
//  Depth.swift
//  Atlas
//

import SwiftUI

/// The four depth levels (README — Design system §6): flat content, cards
/// (a 0.5 pt line plus a 3 pt soft shadow), popovers and menus, and sheets.
/// Popovers, menus and sheets are the system's; `.popover` and `.sheet`
/// are only for the few floating things Atlas draws itself (a toast, a
/// detail card over a map, an image on a viewer's dark stage).
enum Depth {
    case flat
    case card
    case popover
    case sheet

    var opacity: Double {
        switch self {
        case .flat: 0
        case .card: 0.06
        case .popover: 0.14
        case .sheet: 0.5
        }
    }

    var radius: CGFloat {
        switch self {
        case .flat: 0
        case .card: 3
        case .popover: 12
        case .sheet: 30
        }
    }

    var y: CGFloat {
        switch self {
        case .flat: 0
        case .card: 1
        case .popover: 4
        case .sheet: 20
        }
    }
}

extension View {
    /// Lifts the view to one of the four depth levels.
    func depth(_ level: Depth) -> some View {
        shadow(color: .black.opacity(level.opacity), radius: level.radius, y: level.y)
    }
}
