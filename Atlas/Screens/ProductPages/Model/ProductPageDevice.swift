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

    /// The set a page's own screenshots go into on this device: the
    /// largest display, which the smaller ones are made from.
    var displayType: ScreenshotDisplayType {
        switch self {
        case .iPhone: .iPhone
        case .iPad: .iPad
        }
    }

    /// The sizes App Store Connect takes for that set, upright; turned 90°
    /// they're taken too.
    var acceptedSizes: [PixelSize] {
        switch self {
        case .iPhone: [PixelSize(width: 1320, height: 2868), PixelSize(width: 1290, height: 2796), PixelSize(width: 1260, height: 2736)]
        case .iPad: [PixelSize(width: 2064, height: 2752), PixelSize(width: 2048, height: 2732)]
        }
    }

    /// Whether App Store Connect takes a screenshot of `size` for this
    /// device, either way round.
    func accepts(_ size: PixelSize) -> Bool {
        acceptedSizes.contains { $0 == size || $0.rotated == size }
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
