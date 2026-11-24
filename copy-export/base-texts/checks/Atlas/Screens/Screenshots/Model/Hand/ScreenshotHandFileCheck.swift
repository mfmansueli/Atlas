//
//  ScreenshotHandFileCheck.swift
//  Atlas
//

import Foundation

/// Whether a file can go into a device's set the way App Store Connect
/// takes it: a PNG or JPEG without transparency, in one of the device's
/// sizes, upright or turned. Atlas never scales a screenshot to fit: App
/// Review rejects stretched ones.
enum ScreenshotHandFileCheck: Hashable, Sendable {
    case fits
    case unreadable
    case wrongSize(PixelSize)
    case transparent

    init(_ file: ScreenshotHandChosenFile, on display: ScreenshotDisplayType) {
        guard let size = file.pixelSize else {
            self = .unreadable
            return
        }
        if !ScreenshotHandSizes.accepts(size, on: display) {
            self = .wrongSize(size)
        } else if file.hasTransparency {
            self = .transparent
        } else {
            self = .fits
        }
    }

    var fits: Bool { self == .fits }

    /// "Wrong size · skipped", for a list of files.
    var shortTitle: String {
        switch self {
        case .fits: String(localized: "Ready")
        case .unreadable: String(localized: "Not an image · skipped")
        case .wrongSize: String(localized: "Wrong size · skipped")
        case .transparent: String(localized: "Transparent · skipped")
        }
    }

    /// What's wrong and how to fix it; nil when it fits.
    func problem(fileName: String, on display: ScreenshotDisplayType) -> String? {
        switch self {
        case .fits:
            return nil
        case .unreadable:
            return String(localized: "“\(fileName)” isn’t a PNG or JPEG image Atlas can read.")
        case let .wrongSize(size):
            // Pixels are never grouped ("1179", not "1.179").
            let shown = size.title
            return String(localized: "\(shown) isn’t an \(display.title) size. Use \(ScreenshotHandSizes.all(on: display)), upright or turned.")
        case .transparent:
            return String(localized: "“\(fileName)” has transparency, which App Store Connect refuses. Save it without an alpha channel.")
        }
    }
}
