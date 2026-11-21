//
//  PageShotsRecapture.swift
//  Atlas
//

import Foundation

/// Capture screens again (board 52): the person let the assistant capture
/// the screens that should show something else for this page. Its PNGs
/// arrive at the upload link named by `uploadToken`.
struct PageShotsRecapture: Codable, Hashable, Sendable {
    /// At most this many screens are captured again.
    static let maxScreens = 3

    var uploadToken: String
    var captures: [PageShotsNewCapture] = []
    /// The Claude Code session capturing them.
    var claudeRunID: UUID?
    var askedAt: Date?
    var problem: String?

    /// The default set's slots captured again, in order.
    var slots: [Int] { Array(Set(captures.map(\.slot))).sorted() }

    /// The capture of `slot` in `locale` on `displayType`, else the
    /// primary language's.
    func capture(slot: Int, locale: String, displayType: ScreenshotDisplayType, primary: String) -> ResolvedCapture? {
        let onDevice = captures.filter { $0.slot == slot && $0.displayType == displayType }
        if let own = onDevice.last(where: { $0.locale == locale }) {
            return ResolvedCapture(capture: own.capture, isInterfaceLocalized: true)
        }
        if let fallback = onDevice.last(where: { $0.locale == primary }) {
            return ResolvedCapture(capture: fallback.capture, isInterfaceLocalized: locale == primary)
        }
        return nil
    }
}
