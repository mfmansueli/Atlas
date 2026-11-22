//
//  ScreenshotHandTarget.swift
//  Atlas
//

import Foundation

/// What one place of a set changed by hand holds once it's pushed: a
/// screenshot already live (kept, perhaps moved), or the one an item
/// uploads.
enum ScreenshotHandTarget: Hashable, Sendable {
    case keep(liveID: String)
    case upload(itemID: ScreenshotPlanItem.ID)
}
