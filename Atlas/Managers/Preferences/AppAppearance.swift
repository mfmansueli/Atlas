//
//  AppAppearance.swift
//  Atlas
//

import AppKit

/// Settings → General → Appearance: follow macOS, or always light or dark.
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Match System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// Every window follows at once.
    @MainActor
    func apply() {
        NSApp?.appearance = nsAppearance
    }
}
