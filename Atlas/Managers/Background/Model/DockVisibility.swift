//
//  DockVisibility.swift
//  Atlas
//

import Foundation

/// Settings → General → "Show in the Dock". With "Only while a window is
/// open" Atlas lives in the menu bar alone once its windows are closed
/// (the `.accessory` activation policy).
enum DockVisibility: String, CaseIterable, Codable, Sendable {
    case whileWindowOpen
    case always

    var title: String {
        switch self {
        case .whileWindowOpen: String(localized: "Only while a window is open")
        case .always: String(localized: "Always")
        }
    }

    /// Whether the Dock shows Atlas when `hasOpenWindow` says whether a
    /// window (the main one or Settings) is on screen.
    func showsIcon(hasOpenWindow: Bool) -> Bool {
        self == .always || hasOpenWindow
    }
}
