//
//  ScreenshotsEmptyCheck.swift
//  Atlas
//

import Foundation

/// Whether Screenshots has nothing at all yet (board 74 · 4): no
/// screenshot or App Preview on the App Store, no capture, and none added
/// by hand. Then the section explains and offers Add Screenshots…; the
/// toolbar's Make Screenshots… is the other way.
enum ScreenshotsEmptyCheck {
    static func isEmpty(live: LiveScreenshots, document: ScreenshotsDocument?) -> Bool {
        guard let document else { return false }
        let hasLive = live.screenshotSets.contains { !$0.screenshots.isEmpty }
            || live.previewSets.contains { !($0.previews ?? []).isEmpty }
        let hasHand = (document.handSets ?? []).contains { !$0.slots.isEmpty }
        return !hasLive && !hasHand && document.captures.isEmpty
    }
}
