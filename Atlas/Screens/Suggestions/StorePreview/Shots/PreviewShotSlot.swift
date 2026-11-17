//
//  PreviewShotSlot.swift
//  Atlas
//

import CoreGraphics

/// One tile of the App Store preview's screenshot strip: a screenshot on
/// its way, shown, or one Apple has no image for; or a tile standing in
/// while there's no screenshot to show.
struct PreviewShotSlot: Identifiable {
    let id: String
    /// Height ÷ width: the screenshot's own when App Store Connect says,
    /// so the tile keeps the room its image takes once it arrives.
    var aspect: CGFloat
    var phase: ImageLoadPhase
    /// Stands in for a screenshot: while they're read, or when there are
    /// none.
    var isPlaceholder = false
}
