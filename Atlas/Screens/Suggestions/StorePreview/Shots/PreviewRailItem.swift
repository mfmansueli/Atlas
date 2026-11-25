//
//  PreviewRailItem.swift
//  Atlas
//

import Foundation

/// One tile of the App Store preview's row, in the App Store's order: the
/// App Previews first, then every screenshot.
enum PreviewRailItem: Identifiable {
    case appPreview(PreviewAppPreviewSlot)
    case screenshot(PreviewShotSlot)

    var id: String {
        switch self {
        case let .appPreview(slot): "appPreview.\(slot.id)"
        case let .screenshot(slot): "screenshot.\(slot.id)"
        }
    }

    var isAppPreview: Bool {
        if case .appPreview = self { return true }
        return false
    }
}
