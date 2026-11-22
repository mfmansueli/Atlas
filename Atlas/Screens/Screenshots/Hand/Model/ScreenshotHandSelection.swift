//
//  ScreenshotHandSelection.swift
//  Atlas
//

import Foundation

/// The screenshot picked on the language page, to move, replace or delete:
/// a place in one language's set on one device.
struct ScreenshotHandSelection: Hashable, Sendable {
    var locale: String
    var displayType: ScreenshotDisplayType
    var slotID: String
}
