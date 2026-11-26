//
//  StoreArtworkRules.swift
//  Atlas
//

import CoreGraphics

/// Board 78's layout rules for the Screenshots page: the On the App Store
/// preview leaves below 900 pt (the header and search artwork wrap by
/// themselves, `FlowLayout`), and screenshots 1–3 on iPhone are marked
/// "In search" (what search shows without artwork).
enum StoreArtworkRules {
    /// How many screenshots search results show on iPhone.
    static let searchShotCount = 3

    /// The preview sits beside the page only in a window this wide.
    static func showsPreview(pageWidth: CGFloat) -> Bool {
        pageWidth >= Metrics.storeArtworkPreviewMinPageWidth
    }

    /// Whether the screenshot `keptIndex` places in (deleted ones not
    /// counted) shows in search results: the first three, on iPhone.
    static func marksInSearch(keptIndex: Int?, display: ScreenshotDisplayType) -> Bool {
        guard let keptIndex, display == .iPhone else { return false }
        return keptIndex < searchShotCount
    }
}
