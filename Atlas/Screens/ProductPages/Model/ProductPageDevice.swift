//
//  ProductPageDevice.swift
//  Atlas
//

import Foundation

/// The device whose screenshots the editor shows.
enum ProductPageDevice: String, CaseIterable, Identifiable, Hashable, Sendable {
    case iPhone
    case iPad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iPhone: String(localized: "iPhone")
        case .iPad: String(localized: "iPad")
        }
    }

    /// Whether a screenshot set's `screenshotDisplayType` is for this device.
    func matches(_ displayType: String) -> Bool {
        switch self {
        case .iPhone: displayType.hasPrefix("APP_IPHONE")
        case .iPad: displayType.hasPrefix("APP_IPAD")
        }
    }

    /// Whether an App Preview set's `previewType` is for this device.
    func matchesPreview(_ previewType: String) -> Bool {
        switch self {
        case .iPhone: previewType.hasPrefix("IPHONE")
        case .iPad: previewType.hasPrefix("IPAD")
        }
    }
}
