//
//  ScreenshotHandDeviceLine.swift
//  Atlas
//

import Foundation

/// The line above the language page's row: the device, the size its
/// screenshots take, what the row holds (the App Previews first, as on the
/// App Store) and what to do with it.
enum ScreenshotHandDeviceLine {
    /// "Mac · 2880 × 1800 · App Preview and 6 of 10 screenshots. Select a
    /// screenshot to …"; without App Previews "iPhone 6.9″ · 1320 × 2868 ·
    /// 5 of 10. Select a screenshot to …".
    static func text(device: String, size: String, screenshots: Int, capacity: Int, appPreviews: Int) -> String {
        switch appPreviews {
        case ...0:
            String(localized: """
            \(device) · \(size) · \(screenshots) of \(capacity). \
            Select a screenshot to replace, move or delete it, or drop files to add them.
            """)
        case 1:
            String(localized: """
            \(device) · \(size) · App Preview and \(screenshots) of \(capacity) screenshots. \
            Select a screenshot to replace, move or delete it, or drop files to add them.
            """, comment: "kind:description")
        default:
            String(localized: """
            \(device) · \(size) · \(appPreviews) App Previews and \(screenshots) of \(capacity) screenshots. \
            Select a screenshot to replace, move or delete it, or drop files to add them.
            """, comment: "kind:description")
        }
    }
}
