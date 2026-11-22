//
//  CaptureReplacement.swift
//  Atlas
//

import Foundation

/// Replace…: a PNG for one cell, checked with the same size rules as an
/// import (the device's class, big enough for its set) and made into the
/// import item that copies it next to the document. Pure.
enum CaptureReplacement {
    /// Why `size` can't go in `display`'s set; nil when it can.
    static func refusal(size: PixelSize?, for display: ScreenshotDisplayType) -> String? {
        guard let size else { return String(localized: "Atlas couldn’t read that image. Choose a PNG screenshot.") }
        let sizeText = "\(size.width) × \(size.height)"
        guard CaptureSizeRules.isSameDevice(size, as: display) else {
            return String(localized: "That image is \(sizeText): it isn’t a \(display.shortTitle) screenshot.")
        }
        guard CaptureSizeRules.fits(size, in: display) else {
            let smallest = CaptureSizeRules.smallestWidth(for: display)
            return String(localized: "That image is \(sizeText): a \(display.shortTitle) capture is at least \(smallest) pixels wide.")
        }
        return nil
    }

    /// The import item that puts `url` in `cell`.
    static func item(_ url: URL, size: PixelSize, in cell: CaptureCellKey) -> CaptureImportItem {
        CaptureImportItem(
            candidate: CaptureCandidate(
                path: url.lastPathComponent, origin: .file(url), source: .folder, pixelSize: size, localeCode: cell.locale,
                displayType: cell.displayType
            ),
            placement: CaptureMatchRow.Placement(locale: cell.locale, displayType: cell.displayType, slot: cell.slot)
        )
    }
}
