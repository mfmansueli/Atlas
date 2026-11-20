//
//  ProductPageEdits.swift
//  Atlas
//

import Foundation

/// What's queued in Review & Push for one page, read back from the queue so
/// the editor shows it on top of what App Store Connect has.
struct ProductPageEdits: Hashable, Sendable {
    var texts: [String: String] = [:]
    var keywords: [String: [String]] = [:]
    var deepLink: String?
    var name: String?
    var isVisible: Bool?
    var isDeleted = false
    /// The page's own screenshots queued, by locale and device.
    var screenshots: [String: [ScreenshotDisplayType: [ProductPageScreenshotsPush.File]]] = [:]
    /// How many changes: "4 not pushed".
    var count = 0

    var isEmpty: Bool { count == 0 }
}
