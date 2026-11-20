//
//  ProductPageScreenshotsPushOrder.swift
//  Atlas
//

import Foundation

/// A custom product page's own screenshots go after everything else of the
/// push, so the page they belong to (a new one made in Atlas), its texts
/// and its keywords are in App Store Connect first. The rest keep the
/// queue's order.
enum ProductPageScreenshotsPushOrder {
    static func sorted(_ changes: [PendingChange]) -> [PendingChange] {
        changes.filter { !isScreenshots($0) } + changes.filter(isScreenshots)
    }

    static func isScreenshots(_ change: PendingChange) -> Bool {
        change.requests.contains { ProductPageScreenshotsPush($0) != nil }
    }
}
